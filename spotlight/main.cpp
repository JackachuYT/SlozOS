// SlozOS Spotlight — a macOS Tahoe-style search bar for KDE Plasma.
//
// A small Qt Quick host around Main.qml. Search results come from KRunner (via
// the org.kde.milou QML model, the same backend Plasma's own KRunner uses), so
// every installed KRunner plugin works here too.
//
//   slozos-spotlight            toggle the search bar (start it if needed)
//   slozos-spotlight --daemon   start hidden in the background (autostart)
//   slozos-spotlight --screenshot out.png [--query text] [--category n]
//                               render once off-screen and save a PNG (testing)

#include <QCommandLineParser>
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

#include <KWindowEffects>
#include <LayerShellQt/Window>

#include <unistd.h>

static bool onWayland()
{
    return QGuiApplication::platformName().startsWith(QLatin1String("wayland"));
}

class Spotlight : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

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

Q_SIGNALS:
    void toggleRequested();
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("slozos-spotlight"));
    app.setOrganizationDomain(QStringLiteral("slozos.org"));
    app.setDesktopFileName(QStringLiteral("org.slozos.spotlight"));
    app.setQuitOnLastWindowClosed(false);
    // Outside a Plasma session (e.g. --screenshot in CI) no icon theme is set
    if (QIcon::themeName().isEmpty() || QIcon::themeName() == QLatin1String("hicolor")) {
        QIcon::setThemeName(QStringLiteral("breeze-dark"));
    }

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption daemonOpt(QStringLiteral("daemon"), QStringLiteral("Start hidden in the background."));
    QCommandLineOption shotOpt(QStringLiteral("screenshot"), QStringLiteral("Render once and save to <file>."),
                               QStringLiteral("file"));
    QCommandLineOption queryOpt(QStringLiteral("query"), QStringLiteral("Query for --screenshot."), QStringLiteral("text"));
    QCommandLineOption catOpt(QStringLiteral("category"), QStringLiteral("Category for --screenshot."), QStringLiteral("n"),
                              QStringLiteral("-1"));
    parser.addOptions({daemonOpt, shotOpt, queryOpt, catOpt});
    parser.process(app);
    const bool screenshot = parser.isSet(shotOpt);

    // Single instance: a second launch just tells the running one to toggle.
    const QString serverName = QStringLiteral("slozos-spotlight-%1").arg(getuid());
    if (!screenshot) {
        QLocalSocket probe;
        probe.connectToServer(serverName);
        if (probe.waitForConnected(300)) {
            if (!parser.isSet(daemonOpt)) {
                probe.write("toggle");
                probe.waitForBytesWritten(300);
            }
            return 0;
        }
    }

    Spotlight spotlight;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Spotlight"), &spotlight);
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

    QLocalServer::removeServer(serverName);
    QLocalServer server;
    server.listen(serverName);
    QObject::connect(&server, &QLocalServer::newConnection, &server, [&server, &spotlight] {
        while (QLocalSocket *client = server.nextPendingConnection()) {
            QObject::connect(client, &QLocalSocket::readyRead, client, [client, &spotlight] {
                if (client->readAll().contains("toggle")) {
                    Q_EMIT spotlight.toggleRequested();
                }
                client->deleteLater();
            });
        }
    });

    if (!parser.isSet(daemonOpt)) {
        Q_EMIT spotlight.toggleRequested();
    }
    return app.exec();
}

#include "main.moc"
