#pragma once
#include "simulation.h"
#include <QSize>
#include <memory>

class QRhi;
class QRhiCommandBuffer;
class QRhiRenderTarget;
class QRhiTexture;
namespace fireworks {
struct RenderSettings {
    float exposure = 0.95f, bloom = 0.85f;
};
class Renderer {
  public:
    Renderer();
    ~Renderer();
    bool initialize(QRhi *rhi, QRhiRenderTarget *output);
    void render(QRhiCommandBuffer *cb, const Simulation &simulation, const RenderSettings &settings);
    bool hdr() const;
    std::size_t vertexCount() const;
    QRhiTexture *diagnosticTexture(int stage) const;

  private:
    struct Data;
    std::unique_ptr<Data> d;
};
} // namespace fireworks
