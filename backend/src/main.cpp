#include "fireworksview.h"
#include "showdirector.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

int main(int argc, char **argv) {
    qputenv("QT_FORCE_STDERR_LOGGING", "1");
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Fireworks");
    QQuickStyle::setStyle("Basic");
    qmlRegisterType<FireworksView>("Omarchy.Fireworks", 1, 0, "FireworksView");
    qmlRegisterType<ShowDirector>("Omarchy.Fireworks", 1, 0, "ShowDirector");
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("startMuted", app.arguments().contains("--mute"));
    engine.load(QUrl(QStringLiteral("qrc:/qml/Preview.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    const int screenshotArgument = app.arguments().indexOf("--screenshot");
    if (screenshotArgument >= 0 && screenshotArgument + 1 < app.arguments().size()) {
        const auto path = app.arguments()[screenshotArgument + 1];
        QTimer::singleShot(900, &app, [&engine, path] {
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            if (!window || !window->grabWindow().save(path)) {
                qCritical() << "Cannot capture preview window";
                QCoreApplication::exit(1);
            }
        });
    }
    if (app.arguments().contains("--smoke-test"))
        QTimer::singleShot(1800, &app, &QCoreApplication::quit);
    return app.exec();
}
