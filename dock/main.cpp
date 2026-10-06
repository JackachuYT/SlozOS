// SlozOS Dock — a macOS-style dock for KDE Plasma, drawn like MacTahoe's.
//
// A Qt Quick host around Main.qml. Windows and launchers come from Plasma's
// own task manager model (org.kde.taskmanager), so the dock sees exactly the
// apps the Plasma taskbar would. KWin only gives that window list to trusted
// clients: org.slozos.dock.desktop declares
// X-KDE-Wayland-Interfaces=org_kde_plasma_window_management for this binary.
//
//   slozos-dock                  run the dock (autostarted at login)
//   slozos-dock --screenshot f   render once (with sample icons) and save a PNG

#include <QCommandLineParser>
#include <QDir>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QIcon>
#include <QPainterPath>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegion>
#include <QScreen>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

#include <KIO/EmptyTrashJob>
#include <KIO/OpenUrlJob>
#include <KWindowEffects>
#include <LayerShellQt/Window>

static bool onWayland()
{
    return QGuiApplication::platformName().startsWith(QLatin1String("wayland"));
}

static QRegion roundedRegion(const QVariantList &shapes)
{
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
    return region;
}

class Dock : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList launchers READ launchers WRITE setLaunchers NOTIFY launchersChanged)
    Q_PROPERTY(bool autoHide READ autoHide NOTIFY settingsChanged)
    Q_PROPERTY(bool trashFull READ trashFull NOTIFY trashChanged)
public:
    explicit Dock(QObject *parent = nullptr)
        : QObject(parent)
        , m_settings(QDir(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation))
                         .filePath(QStringLiteral("slozos/dockrc")),
                     QSettings::IniFormat)
    {
        // Settings can change from outside (SlozOS Welcome's "hide the dock" toggle)
        m_watcher.addPath(m_settings.fileName());
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &path) {
            m_settings.sync();
            if (!m_watcher.files().contains(path)) {
                m_watcher.addPath(path);   // rewritten files drop off the watch list
            }
            Q_EMIT settingsChanged();
            Q_EMIT launchersChanged();
        });

        const QString trash = QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
                                  .filePath(QStringLiteral("Trash/files"));
        QDir().mkpath(trash);
        m_trashDir = trash;
        m_watcher.addPath(trash);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Dock::trashChanged);
    }

    QStringList launchers() const
    {
        static const QStringList defaults{
            QStringLiteral("preferred://filemanager"),
            QStringLiteral("preferred://browser"),
            QStringLiteral("applications:steam.desktop"),
            QStringLiteral("applications:net.lutris.Lutris.desktop"),
            QStringLiteral("applications:io.github.kolunmi.Bazaar.desktop"),
            QStringLiteral("applications:org.kde.konsole.desktop"),
            QStringLiteral("applications:systemsettings.desktop"),
        };
        return m_settings.value(QStringLiteral("launchers"), defaults).toStringList();
    }

    void setLaunchers(const QStringList &list)
    {
        if (list == launchers()) {
            return;
        }
        m_settings.setValue(QStringLiteral("launchers"), list);
        m_settings.sync();
        if (!m_watcher.files().contains(m_settings.fileName())) {
            m_watcher.addPath(m_settings.fileName());
        }
        Q_EMIT launchersChanged();
    }

    // "Hide the dock when a window needs the space" (SlozOS Welcome)
    bool autoHide() const
    {
        return m_settings.value(QStringLiteral("autoHide"), true).toBool();
    }

    bool trashFull() const
    {
        return !QDir(m_trashDir).isEmpty(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
    }

    // Blur behind the glass shelf, and take input only where the dock is drawn
    // (the window is taller than the shelf so icons can magnify upwards)
    Q_INVOKABLE void setShape(QQuickWindow *window, const QVariantList &blur, const QVariantList &input) const
    {
        if (!window) {
            return;
        }
        KWindowEffects::enableBlurBehind(window, true, roundedRegion(blur));
        window->setMask(roundedRegion(input));
    }

    // Space windows keep clear of (0 while auto-hiding, like Plasma's "dodge windows")
    Q_INVOKABLE void setExclusiveZone(QQuickWindow *window, int zone) const
    {
        if (window && onWayland()) {
            LayerShellQt::Window::get(window)->setExclusiveZone(zone);
        }
    }

    // A right-click menu takes keyboard focus so clicking anywhere else (which
    // moves focus away) closes it; the rest of the time the dock never has focus
    Q_INVOKABLE void setFocusable(QQuickWindow *window, bool focusable) const
    {
        if (!window || !onWayland()) {
            return;
        }
        LayerShellQt::Window::get(window)->setKeyboardInteractivity(
            focusable ? LayerShellQt::Window::KeyboardInteractivityOnDemand : LayerShellQt::Window::KeyboardInteractivityNone);
        if (focusable) {
            window->requestActivate();
        }
    }

    Q_INVOKABLE void run(const QString &program, const QStringList &args = {}) const
    {
        QProcess::startDetached(program, args);
    }

    Q_INVOKABLE void openTrash() const
    {
        auto *job = new KIO::OpenUrlJob(QUrl(QStringLiteral("trash:/")));
        job->start();
    }

    Q_INVOKABLE void emptyTrash() const
    {
        KIO::emptyTrash()->start();
    }

Q_SIGNALS:
    void launchersChanged();
    void settingsChanged();
    void trashChanged();

private:
    QSettings m_settings;
    QFileSystemWatcher m_watcher;
    QString m_trashDir;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("slozos-dock"));
    app.setOrganizationDomain(QStringLiteral("slozos.org"));
    app.setDesktopFileName(QStringLiteral("org.slozos.dock"));
    app.setQuitOnLastWindowClosed(false);
    app.setQuitLockEnabled(false);
    if (QIcon::themeName().isEmpty() || QIcon::themeName() == QLatin1String("hicolor")) {
        QIcon::setThemeName(QStringLiteral("breeze-dark"));
    }

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption shotOpt(QStringLiteral("screenshot"), QStringLiteral("Render once and save to <file>."),
                               QStringLiteral("file"));
    QCommandLineOption hoverOpt(QStringLiteral("hover"), QStringLiteral("Pointer x for --screenshot (magnification)."),
                                QStringLiteral("x"), QStringLiteral("-1"));
    parser.addOptions({shotOpt, hoverOpt});
    parser.process(app);
    const bool screenshot = parser.isSet(shotOpt);

    Dock dock;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Dock"), &dock);
    engine.rootContext()->setContextProperty(QStringLiteral("previewMode"), screenshot);
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());

    if (onWayland()) {
        // Along the bottom of the primary screen, above normal windows (but
        // below fullscreen games), never taking the keyboard
        window->setScreen(QGuiApplication::primaryScreen());
        auto *layer = LayerShellQt::Window::get(window);
        layer->setLayer(LayerShellQt::Window::LayerTop);
        layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorBottom | LayerShellQt::Window::AnchorLeft
                                                        | LayerShellQt::Window::AnchorRight));
        layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        layer->setScope(QStringLiteral("slozos-dock"));
    }

    if (screenshot) {
        const QString out = parser.value(shotOpt);
        window->setProperty("previewHover", parser.value(hoverOpt).toDouble());
        window->show();
        QTimer::singleShot(2500, &app, [window, out, &app] {
            window->grabWindow().save(out);
            app.quit();
        });
        return app.exec();
    }

    window->show();
    return app.exec();
}

#include "main.moc"
