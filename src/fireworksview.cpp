#include "fireworksview.h"
#include "renderer.h"
#include <algorithm>
#include <cmath>

class ViewRenderer : public QQuickRhiItemRenderer {
    fireworks::Simulation simulation;
    fireworks::Renderer renderer;
    fireworks::RenderSettings settings;
    double targetTime = 0;
    float wind = 2.2f;
    bool ready = false;
    void initialize(QRhiCommandBuffer *) override { ready = renderer.initialize(rhi(), renderTarget()); }
    void synchronize(QQuickRhiItem *item) override {
        auto *view = static_cast<FireworksView *>(item);
        auto seed = std::uint32_t(view->seed());
        const auto shell = fireworks::ShellType(view->shellType());
        if (seed != simulation.seed() || wind != view->wind() || shell != simulation.shellType()) {
            simulation.setShellType(shell);
            simulation.reset(seed);
            wind = view->wind();
            simulation.setWind(wind);
        }
        // setOrigin resets the show on its own when the value actually moves,
        // so it is set unconditionally rather than folded into the test above.
        simulation.setOrigin(view->originX());
        targetTime = view->time();
        settings = {view->exposure(), view->bloom()};
    }
    void render(QRhiCommandBuffer *cb) override {
        if (!ready)
            return;
        simulation.advanceTo(targetTime, 180);
        renderer.render(cb, simulation, settings);
        if (simulation.time() + fireworks::Simulation::Step < targetTime)
            update();
    }
};
FireworksView::FireworksView(QQuickItem *parent) : QQuickRhiItem(parent) { setAlphaBlending(true); }
QQuickRhiItemRenderer *FireworksView::createRenderer() { return new ViewRenderer; }
void FireworksView::setTime(double v) {
    if (!std::isfinite(v))
        return;
    v = std::clamp(v, 0.0, fireworks::Simulation::Duration);
    if (m_time == v)
        return;
    m_time = v;
    emit timeChanged();
    update();
}
void FireworksView::setSeed(int v) {
    if (m_seed == v)
        return;
    m_seed = v;
    emit seedChanged();
    update();
}
void FireworksView::setShellType(int v) {
    v = std::clamp(v, 0, int(fireworks::Shells.size()) - 1);
    if (m_shellType == v)
        return;
    m_shellType = v;
    emit shellTypeChanged();
    update();
}
void FireworksView::setExposure(float v) {
    if (!std::isfinite(v))
        return;
    v = std::clamp(v, 0.1f, 3.f);
    if (m_exposure == v)
        return;
    m_exposure = v;
    emit exposureChanged();
    update();
}
void FireworksView::setBloom(float v) {
    if (!std::isfinite(v))
        return;
    v = std::clamp(v, 0.f, 3.f);
    if (m_bloom == v)
        return;
    m_bloom = v;
    emit bloomChanged();
    update();
}
void FireworksView::setOriginX(float v) {
    if (!std::isfinite(v))
        return;
    v = std::clamp(v, -fireworks::LaunchSpread, fireworks::LaunchSpread);
    if (m_originX == v)
        return;
    m_originX = v;
    emit originXChanged();
    update();
}
void FireworksView::setWind(float v) {
    if (!std::isfinite(v))
        return;
    v = std::clamp(v, -15.f, 15.f);
    if (m_wind == v)
        return;
    m_wind = v;
    emit windChanged();
    update();
}
