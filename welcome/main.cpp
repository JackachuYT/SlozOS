// SlozOS Welcome — first-run setup app (replaces Bazzite's Portal on first login).
//
//   slozos-welcome              open the app
//   slozos-welcome --first-run  open only if setup hasn't been finished yet (autostart)
//   slozos-welcome --screenshot out.png [--page n]   render a page off-screen (testing)

#include <QCommandLineParser>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QImageReader>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>
#include <QUrl>

static QString doneStamp()
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/slozos-welcome-done");
}

class Sys : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap os READ os CONSTANT)
public:
    using QObject::QObject;

    // SLOZOS_VERSION / SLOZOS_EDITION from os-release
    QVariantMap os() const
    {
        QVariantMap m;
        QFile f(QStringLiteral("/usr/lib/os-release"));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&f);
            while (!in.atEnd()) {
                const QString line = in.readLine();
                const int eq = line.indexOf(QLatin1Char('='));
                if (eq > 0) {
                    QString v = line.mid(eq + 1);
                    if (v.startsWith(QLatin1Char('"')) && v.endsWith(QLatin1Char('"')))
                        v = v.mid(1, v.size() - 2);
                    m.insert(line.left(eq), v);
                }
            }
        }
        return m;
    }

    // Run a short shell command and return its output (status checks)
    Q_INVOKABLE QString run(const QString &cmd) const
    {
        QProcess p;
        p.start(QStringLiteral("bash"), {QStringLiteral("-c"), cmd});
        if (!p.waitForFinished(8000)) {
            p.kill();
            return QString();
        }
        return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
    }

    Q_INVOKABLE bool succeeds(const QString &cmd) const
    {
        QProcess p;
        p.start(QStringLiteral("bash"), {QStringLiteral("-c"), cmd});
        return p.waitForFinished(8000) && p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
    }

    // Long-running command (installs); reports back through finished()
    Q_INVOKABLE void runAsync(const QString &id, const QString &cmd)
    {
        auto *p = new QProcess(this);
        p->setProcessChannelMode(QProcess::MergedChannels);
        connect(p, &QProcess::finished, this, [this, p, id](int code, QProcess::ExitStatus status) {
            Q_EMIT finished(id, status == QProcess::NormalExit ? code : -1, QString::fromUtf8(p->readAll()).trimmed());
            p->deleteLater();
        });
        p->start(QStringLiteral("bash"), {QStringLiteral("-c"), cmd});
    }

    // Wallpapers installed on the system: one image per wallpaper package
    Q_INVOKABLE QVariantList wallpapers() const
    {
        QVariantList out;
        const QDir root(QStringLiteral("/usr/share/wallpapers"));
        const QStringList images = {QStringLiteral("*.png"), QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"), QStringLiteral("*.jxl"), QStringLiteral("*.webp")};
        auto add = [&out](const QFileInfo &fi, const QString &name) {
            out.append(QVariantMap{{QStringLiteral("path"), fi.absoluteFilePath()}, {QStringLiteral("name"), name}});
        };
        // SlozOS first
        const QString sloz = QStringLiteral("/usr/share/wallpapers/SlozOS/contents/images/slozos-default.png");
        if (QFile::exists(sloz))
            add(QFileInfo(sloz), QStringLiteral("SlozOS"));
        for (const QFileInfo &entry : root.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::Name)) {
            if (entry.fileName() == QLatin1String("SlozOS"))
                continue;
            if (entry.isDir()) {
                QDir imgs(entry.absoluteFilePath() + QStringLiteral("/contents/images"));
                if (!imgs.exists())
                    imgs = QDir(entry.absoluteFilePath());
                // largest image = best quality
                QFileInfoList files = imgs.entryInfoList(images, QDir::Files, QDir::Size);
                if (!files.isEmpty())
                    add(files.first(), entry.fileName());
            } else if (QImageReader::imageFormat(entry.absoluteFilePath()).size() > 0) {
                add(entry, entry.completeBaseName());
            }
            if (out.size() >= 12)
                break;
        }
        return out;
    }

    Q_INVOKABLE void openUrl(const QString &url) const { QDesktopServices::openUrl(QUrl(url)); }

    Q_INVOKABLE void markDone() const
    {
        QDir().mkpath(QFileInfo(doneStamp()).absolutePath());
        QFile f(doneStamp());
        f.open(QIODevice::WriteOnly);
    }

Q_SIGNALS:
    void finished(const QString &id, int exitCode, const QString &output);
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("slozos-welcome"));
    app.setApplicationDisplayName(QStringLiteral("Welcome to SlozOS"));
    app.setDesktopFileName(QStringLiteral("org.slozos.welcome"));
    if (QIcon::themeName().isEmpty() || QIcon::themeName() == QLatin1String("hicolor"))
        QIcon::setThemeName(QStringLiteral("breeze-dark"));

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption firstRun(QStringLiteral("first-run"), QStringLiteral("Only open if setup isn't finished."));
    QCommandLineOption shot(QStringLiteral("screenshot"), QStringLiteral("Render and save to <file>."), QStringLiteral("file"));
    QCommandLineOption page(QStringLiteral("page"), QStringLiteral("Page for --screenshot."), QStringLiteral("n"), QStringLiteral("0"));
    parser.addOptions({firstRun, shot, page});
    parser.process(app);

    if (parser.isSet(firstRun) && QFile::exists(doneStamp()))
        return 0;

    Sys sys;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Sys"), &sys);
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());

    if (parser.isSet(shot)) {
        window->setProperty("page", parser.value(page).toInt());
        const QString out = parser.value(shot);
        QTimer::singleShot(2500, &app, [window, out, &app] {
            window->grabWindow().save(out);
            app.quit();
        });
    }
    return app.exec();
}

#include "main.moc"
