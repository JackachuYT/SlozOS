// SlozOS Spotlight — a macOS Tahoe-style search bar for KDE Plasma.
//
// A small Qt Quick host around Main.qml. Search results come from KRunner (via
// the org.kde.milou QML model, the same backend Plasma's own KRunner uses), so
// every installed KRunner plugin works here too.
//
//   slozos-spotlight            toggle the search bar (start it if needed)
//   slozos-spotlight --apps     open straight to the Apps grid (the dock's Apps button)
//   slozos-spotlight --daemon   start hidden in the background (autostart)
//   slozos-spotlight --screenshot out.png [--query text] [--category n]
//                               render once off-screen and save a PNG (testing)
//
// Also on D-Bus as org.slozos.Spotlight (/Spotlight: Toggle, ShowApps), used
// by the touchscreen edge swipe. Game controllers work too (see Gamepads).

#include <QCollator>
#include <QCommandLineParser>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QGuiApplication>
#include <QIcon>
#include <QLocalServer>
#include <QLocalSocket>
#include <QPainterPath>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegion>
#include <QScreen>
#include <QTimer>

#include <KApplicationTrader>
#include <KIO/ApplicationLauncherJob>
#include <KService>
#include <KWindowEffects>
#include <LayerShellQt/Window>

#include <SDL3/SDL.h>

#include <unistd.h>

static bool onWayland()
{
    return QGuiApplication::platformName().startsWith(QLatin1String("wayland"));
}

class Spotlight : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.slozos.Spotlight")
public:
    using QObject::QObject;

public Q_SLOTS:
    Q_SCRIPTABLE void Toggle() { Q_EMIT toggleRequested(); }
    Q_SCRIPTABLE void ShowApps() { Q_EMIT appsRequested(); }

public:

    // Klipper (Plasma's clipboard manager) history, newest first
    Q_INVOKABLE QStringList clipboardHistory() const
    {
        QDBusInterface klipper(QStringLiteral("org.kde.klipper"), QStringLiteral("/klipper"),
                               QStringLiteral("org.kde.klipper.klipper"));
        QDBusReply<QStringList> reply = klipper.call(QStringLiteral("getClipboardHistoryMenu"));
        return reply.isValid() ? reply.value() : QStringList();
    }

    // Through Klipper rather than QClipboard: on Wayland a hidden window can't
    // keep clipboard ownership, Klipper can.
    Q_INVOKABLE void copyToClipboard(const QString &text) const
    {
        QDBusInterface klipper(QStringLiteral("org.kde.klipper"), QStringLiteral("/klipper"),
                               QStringLiteral("org.kde.klipper.klipper"));
        klipper.call(QStringLiteral("setClipboardContents"), text);
    }

    // Ask KWin to blur behind the given rounded rectangles ({x, y, width, height, radius})
    Q_INVOKABLE void setBlur(QQuickWindow *window, const QVariantList &shapes) const
    {
        if (!window) {
            return;
        }
        QRegion region;
        for (const QVariant &v : shapes) {
            const QVariantMap m = v.toMap();
            const QRectF r(m.value(QStringLiteral("x")).toReal(), m.value(QStringLiteral("y")).toReal(),
                           m.value(QStringLiteral("width")).toReal(), m.value(QStringLiteral("height")).toReal());
            const qreal radius = m.value(QStringLiteral("radius")).toReal();
            QPainterPath path;
            path.addRoundedRect(r, radius, radius);
            region += QRegion(path.toFillPolygon().toPolygon());
        }
        KWindowEffects::enableBlurBehind(window, true, region);
    }

    // Float the bar about a fifth of the way down the screen it opens on
    Q_INVOKABLE void place(QQuickWindow *window) const
    {
        if (!window || !onWayland()) {
            return;
        }
        QScreen *screen = window->screen() ? window->screen() : QGuiApplication::primaryScreen();
        const int top = screen ? int(screen->geometry().height() * 0.18) : 160;
        LayerShellQt::Window::get(window)->setMargins(QMargins(0, top, 0, 0));
    }

    // Every app that would show in a launcher, sorted by name, for the Apps grid
    Q_INVOKABLE QVariantList applications() const
    {
        KService::List apps = KApplicationTrader::query([](const KService::Ptr &s) {
            return !s->noDisplay() && s->showOnCurrentPlatform()
                && s->storageId() != QLatin1String("org.slozos.apps.desktop");
        });
        QCollator collator;
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        std::sort(apps.begin(), apps.end(), [&collator](const KService::Ptr &a, const KService::Ptr &b) {
            return collator.compare(a->name(), b->name()) < 0;
        });
        QVariantList out;
        for (const KService::Ptr &s : apps) {
            out.append(QVariantMap{{QStringLiteral("name"), s->name()},
                                   {QStringLiteral("icon"), s->icon()},
                                   {QStringLiteral("keywords"), (s->genericName() + QLatin1Char(' ') + s->keywords().join(QLatin1Char(' '))).toLower()},
                                   {QStringLiteral("id"), s->storageId()}});
        }
        return out;
    }

    Q_INVOKABLE void launch(const QString &storageId) const
    {
        if (KService::Ptr service = KService::serviceByStorageId(storageId)) {
            (new KIO::ApplicationLauncherJob(service))->start();
        }
    }

Q_SIGNALS:
    void toggleRequested();
    void appsRequested();
};

// Game controllers, through SDL3. The Guide (Xbox/PS/Home) button opens the
// Apps grid; while Spotlight is open the D-pad or left stick moves, A opens,
// B goes back and LB/RB switch category.
//
// Steam does all of this itself when it's running (its desktop controller
// layout types arrow keys, Enter and Escape, and the Guide button belongs to
// Steam), so everything here pauses while Steam is open.
class Gamepads : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active MEMBER m_active WRITE setActive)
public:
    explicit Gamepads(QObject *parent = nullptr)
        : QObject(parent)
    {
        SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
        // leave SIGTERM/SIGINT to Qt, or logging out would wait on us
        SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
        // evdev only: SDL's HIDAPI drivers send init/LED/rumble packets, which
        // would disturb controllers a game or Steam is using
        SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI, "0");
        if (!SDL_Init(SDL_INIT_GAMEPAD)) {
            qWarning("Gamepads unavailable: %s", SDL_GetError());
            return;
        }
        m_ok = true;
        connect(&m_timer, &QTimer::timeout, this, &Gamepads::poll);
        m_timer.start(50);
        m_steamCheck.start();
    }
    ~Gamepads() override
    {
        if (m_ok) {
            SDL_Quit();
        }
    }

    void setActive(bool active)
    {
        m_active = active;
        m_held.clear();
        m_timer.setInterval(active ? 16 : 50);
    }

Q_SIGNALS:
    // "guide", "a", "b", "lb", "rb", "up", "down", "left", "right"
    void pressed(const QString &button);

private:
    static bool steamRunning()
    {
        const QStringList pids = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &pid : pids) {
            QFile comm(QStringLiteral("/proc/%1/comm").arg(pid));
            if (comm.open(QIODevice::ReadOnly) && comm.readAll().trimmed() == "steam") {
                return true;
            }
        }
        return false;
    }

    QString direction() const
    {
        constexpr int deadzone = 16000;
        for (SDL_Gamepad *pad : m_pads) {
            if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_UP)) return QStringLiteral("up");
            if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_DOWN)) return QStringLiteral("down");
            if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_LEFT)) return QStringLiteral("left");
            if (SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_RIGHT)) return QStringLiteral("right");
            const int x = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTX);
            const int y = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTY);
            if (qMax(qAbs(x), qAbs(y)) > deadzone) {
                return qAbs(x) > qAbs(y) ? (x < 0 ? QStringLiteral("left") : QStringLiteral("right"))
                                         : (y < 0 ? QStringLiteral("up") : QStringLiteral("down"));
            }
        }
        return {};
    }

    void poll()
    {
        if (m_steamCheck.elapsed() > 2000) {
            m_steam = steamRunning();
            m_steamCheck.restart();
        }
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_EVENT_GAMEPAD_ADDED) {
                if (SDL_Gamepad *pad = SDL_OpenGamepad(e.gdevice.which)) {
                    m_pads.append(pad);
                }
            } else if (e.type == SDL_EVENT_GAMEPAD_REMOVED) {
                if (SDL_Gamepad *pad = SDL_GetGamepadFromID(e.gdevice.which)) {
                    m_pads.removeAll(pad);
                    SDL_CloseGamepad(pad);
                }
            } else if (e.type == SDL_EVENT_GAMEPAD_BUTTON_DOWN && !m_steam) {
                switch (e.gbutton.button) {
                case SDL_GAMEPAD_BUTTON_GUIDE: Q_EMIT pressed(QStringLiteral("guide")); break;
                case SDL_GAMEPAD_BUTTON_SOUTH: if (m_active) Q_EMIT pressed(QStringLiteral("a")); break;
                case SDL_GAMEPAD_BUTTON_EAST: if (m_active) Q_EMIT pressed(QStringLiteral("b")); break;
                case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER: if (m_active) Q_EMIT pressed(QStringLiteral("lb")); break;
                case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: if (m_active) Q_EMIT pressed(QStringLiteral("rb")); break;
                default: break;
                }
            }
        }
        if (!m_active || m_steam) {
            return;
        }
        // Directions repeat while held, like a key: first after 400 ms, then every 120 ms
        const QString dir = direction();
        if (dir != m_held) {
            m_held = dir;
            if (!dir.isEmpty()) {
                Q_EMIT pressed(dir);
                m_repeat.start();
                m_nextRepeat = 400;
            }
        } else if (!dir.isEmpty() && m_repeat.elapsed() >= m_nextRepeat) {
            Q_EMIT pressed(dir);
            m_nextRepeat = m_repeat.elapsed() + 120;
        }
    }

    bool m_ok = false;
    bool m_active = false;
    bool m_steam = false;
    QList<SDL_Gamepad *> m_pads;
    QTimer m_timer;
    QElapsedTimer m_steamCheck;
    QElapsedTimer m_repeat;
    qint64 m_nextRepeat = 0;
    QString m_held;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("slozos-spotlight"));
    app.setOrganizationDomain(QStringLiteral("slozos.org"));
    app.setDesktopFileName(QStringLiteral("org.slozos.spotlight"));
    app.setQuitOnLastWindowClosed(false);
    // A daemon with no visible window: finished KIO/KRunner jobs must not
    // count as "nothing left to do" and quit the app
    app.setQuitLockEnabled(false);
    // Outside a Plasma session (e.g. --screenshot in CI) no icon theme is set
    if (QIcon::themeName().isEmpty() || QIcon::themeName() == QLatin1String("hicolor")) {
        QIcon::setThemeName(QStringLiteral("breeze-dark"));
    }

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption daemonOpt(QStringLiteral("daemon"), QStringLiteral("Start hidden in the background."));
    QCommandLineOption appsOpt(QStringLiteral("apps"), QStringLiteral("Open to the Apps grid."));
    QCommandLineOption shotOpt(QStringLiteral("screenshot"), QStringLiteral("Render once and save to <file>."),
                               QStringLiteral("file"));
    QCommandLineOption queryOpt(QStringLiteral("query"), QStringLiteral("Query for --screenshot."), QStringLiteral("text"));
    QCommandLineOption catOpt(QStringLiteral("category"), QStringLiteral("Category for --screenshot."), QStringLiteral("n"),
                              QStringLiteral("-1"));
    parser.addOptions({daemonOpt, appsOpt, shotOpt, queryOpt, catOpt});
    parser.process(app);
    const bool screenshot = parser.isSet(shotOpt);

    // Single instance: a second launch just tells the running one to toggle.
    const QString serverName = QStringLiteral("slozos-spotlight-%1").arg(getuid());
    if (!screenshot) {
        QLocalSocket probe;
        probe.connectToServer(serverName);
        if (probe.waitForConnected(300)) {
            if (!parser.isSet(daemonOpt)) {
                probe.write(parser.isSet(appsOpt) ? "apps" : "toggle");
                probe.waitForBytesWritten(300);
            }
            return 0;
        }
    }

    Spotlight spotlight;
    Gamepads *gamepads = screenshot ? nullptr : new Gamepads(&app);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Spotlight"), &spotlight);
    engine.rootContext()->setContextProperty(QStringLiteral("Gamepads"), gamepads);
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());

    if (onWayland()) {
        // A layer-shell overlay: floats above everything (incl. panels and
        // fullscreen windows), centred on the active screen, takes the keyboard.
        auto *layer = LayerShellQt::Window::get(window);
        layer->setLayer(LayerShellQt::Window::LayerOverlay);
        layer->setAnchors(LayerShellQt::Window::AnchorTop);
        layer->setExclusiveZone(-1);
        layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
        layer->setActivateOnShow(true);
        layer->setWantsToBeOnActiveScreen(true);
        layer->setScope(QStringLiteral("slozos-spotlight"));
    }

    if (screenshot) {
        const QString out = parser.value(shotOpt);
        QMetaObject::invokeMethod(window, "open", Q_ARG(QVariant, parser.value(queryOpt)),
                                  Q_ARG(QVariant, parser.value(catOpt).toInt()));
        QTimer::singleShot(3000, &app, [window, out, &app] {
            window->grabWindow().save(out);
            app.quit();
        });
        return app.exec();
    }

    QDBusConnection::sessionBus().registerObject(QStringLiteral("/Spotlight"), &spotlight,
                                                 QDBusConnection::ExportScriptableSlots);
    QDBusConnection::sessionBus().registerService(QStringLiteral("org.slozos.Spotlight"));

    QLocalServer::removeServer(serverName);
    QLocalServer server;
    server.listen(serverName);
    QObject::connect(&server, &QLocalServer::newConnection, &server, [&server, &spotlight] {
        while (QLocalSocket *client = server.nextPendingConnection()) {
            QObject::connect(client, &QLocalSocket::readyRead, client, [client, &spotlight] {
                const QByteArray msg = client->readAll();
                if (msg.contains("apps")) {
                    Q_EMIT spotlight.appsRequested();
                } else if (msg.contains("toggle")) {
                    Q_EMIT spotlight.toggleRequested();
                }
                client->deleteLater();
            });
        }
    });

    if (parser.isSet(appsOpt)) {
        Q_EMIT spotlight.appsRequested();
    } else if (!parser.isSet(daemonOpt)) {
        Q_EMIT spotlight.toggleRequested();
    }
    return app.exec();
}

#include "main.moc"
