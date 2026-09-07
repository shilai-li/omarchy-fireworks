#include "fireworksview.h"
#include "showdirector.h"
#include <QQmlExtensionPlugin>

class FireworksPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
  public:
    void registerTypes(const char *uri) override {
        qmlRegisterType<FireworksView>(uri, 1, 0, "FireworksView");
        qmlRegisterType<ShowDirector>(uri, 1, 0, "ShowDirector");
    }
};
#include "plugin.moc"
