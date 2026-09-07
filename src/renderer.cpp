#include "renderer.h"
#include <QFile>
#include <QMatrix4x4>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <rhi/qrhi.h>

namespace fireworks {
namespace {
template <class T> using Owned = std::unique_ptr<T>;
struct Vertex {
    float x, y, u, v, r, g, b, a, kind, seed, age, pad;
};
struct Color {
    float r, g, b, a;
    Color operator*(float f) const { return {r * f, g * f, b * f, a * f}; }
};
struct Point {
    float x, y, scale;
};
struct Target {
    Owned<QRhiTexture> texture;
    Owned<QRhiRenderPassDescriptor> pass;
    Owned<QRhiTextureRenderTarget> target;
    bool create(QRhi *rhi, QSize size, QRhiTexture::Format format) {
        texture.reset(
            rhi->newTexture(format, size, 1, QRhiTexture::RenderTarget | QRhiTexture::UsedAsTransferSource));
        if (!texture->create())
            return false;
        target.reset(rhi->newTextureRenderTarget(
            QRhiTextureRenderTargetDescription(QRhiColorAttachment(texture.get()))));
        pass.reset(target->newCompatibleRenderPassDescriptor());
        target->setRenderPassDescriptor(pass.get());
        return target->create();
    }
};
QShader shader(const char *name) {
    QFile file(QStringLiteral(":/fireworks/") + QString::fromLatin1(name) + QStringLiteral(".qsb"));
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Cannot load shader" << file.fileName();
        return {};
    }
    return QShader::fromSerialized(file.readAll());
}
float smooth(float a, float b, float x) {
    float t = std::clamp((x - a) / (b - a), 0.f, 1.f);
    return t * t * (3 - 2 * t);
}
} // namespace
struct Renderer::Data {
    QRhi *rhi = nullptr;
    QRhiRenderTarget *output = nullptr;
    QSize size;
    bool floating = false, ready = false;
    Target scene, halfA, halfB, wideA, wideB;
    Owned<QRhiBuffer> vertices, frame;
    Owned<QRhiSampler> sampler;
    Owned<QRhiShaderResourceBindings> sceneBindings;
    Owned<QRhiGraphicsPipeline> lightPipeline, smokePipeline;
    struct Pass {
        Owned<QRhiBuffer> uniforms;
        Owned<QRhiShaderResourceBindings> bindings;
        Owned<QRhiGraphicsPipeline> pipeline;
        QRhiRenderTarget *target = nullptr;
        float dx = 0, dy = 0;
        int mode = 0;
    };
    std::array<Pass, 7> post;
    std::vector<Vertex> geometry;
    std::size_t smokeVertices = 0;
    std::size_t bufferSize = 0;
    float focal = 1;

    Point project(Vec3 p) const {
        const float scale = focal / std::max(180.f, 540.f - p.z);
        return {size.width() * 0.5f + p.x * scale, size.height() * 0.5f - (p.y - 110.f) * scale, scale};
    }
    Vertex vertex(float x, float y, float u, float v, Color c, float kind, float seed, float age) const {
        return {x * 2.f / size.width() - 1.f,
                1.f - y * 2.f / size.height(),
                u,
                v,
                c.r,
                c.g,
                c.b,
                c.a,
                kind,
                seed,
                age,
                0};
    }
    void quad(Point p, float radius, Color c, float kind, float seed = 0, float age = 0) {
        if (p.x + radius < 0 || p.y + radius < 0 || p.x - radius > size.width() ||
            p.y - radius > size.height())
            return;
        const auto a = vertex(p.x - radius, p.y - radius, 0, 0, c, kind, seed, age);
        const auto b = vertex(p.x + radius, p.y - radius, 1, 0, c, kind, seed, age);
        const auto e = vertex(p.x - radius, p.y + radius, 0, 1, c, kind, seed, age);
        const auto f = vertex(p.x + radius, p.y + radius, 1, 1, c, kind, seed, age);
        geometry.insert(geometry.end(), {a, b, e, e, b, f});
    }
    void line(Point a, Point b, float width, Color ca, Color cb) {
        float dx = b.x - a.x, dy = b.y - a.y;
        float len = std::sqrt(dx * dx + dy * dy);
        if (len < 0.025f)
            return;
        float nx = -dy / len * width, ny = dx / len * width;
        auto p = vertex(a.x + nx, a.y + ny, 0, 0, ca, 1, 0, 0);
        auto q = vertex(a.x - nx, a.y - ny, 0, 1, ca, 1, 0, 0);
        auto r = vertex(b.x + nx, b.y + ny, 1, 0, cb, 1, 0, 0);
        auto s = vertex(b.x - nx, b.y - ny, 1, 1, cb, 1, 0, 0);
        geometry.insert(geometry.end(), {p, q, r, r, q, s});
    }
    void buildGeometry(const Simulation &sim) {
        geometry.clear();
        // Keep wide palm fronds framed when the preview is tiled narrowly.
        focal = std::min(size.height() * 1.35f, size.width() * 1.10f);
        const float t = float(sim.time()), burstAge = t - float(Simulation::BurstTime);
        const auto &shell = shellDefinition(sim.shellType());
        const float scale = size.height() / 1080.f;
        for (const auto &s : sim.smoke()) {
            float age = s.age / s.lifetime;
            float alpha = (1 - smooth(0.5f, 1.f, age)) * smooth(0, 0.18f, s.age) * 0.035f;
            const Vec3 distance = s.position - sim.burstPosition();
            const float attenuation = std::exp(
                -(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z) / 9000.f);
            float light = sim.burst()
                              ? (std::exp(-std::max(0.f, burstAge) * 1.15f) * 2.5f + 0.07f) * attenuation
                              : 0.08f;
            const auto p = project(s.position);
            const auto tint = sparkRgb(s.color);
            quad(p, (s.radius + s.age * 3.2f) * p.scale,
                 {0.11f + light * tint.r, 0.11f + light * tint.g, 0.12f + light * tint.b, alpha}, 2, s.seed,
                 s.age);
        }
        smokeVertices = geometry.size();
        if (!sim.finished()) {
            const auto &trail = sim.rocketTrail();
            for (std::size_t i = 1; i < trail.size(); ++i) {
                float age = t - trail[i].time;
                if (age > 0.65f)
                    continue;
                float fade = std::pow(1 - age / 0.65f, 2.f);
                Color c{6.f * fade, 2.35f * fade, 0.35f * fade, 0.7f * fade};
                line(project(trail[i - 1].position), project(trail[i].position), 1.7f * scale, c * 0.96f, c);
            }
            if (!sim.burst())
                quad(project(sim.rocket()), 6.5f * scale, {13, 7, 2.2f, 1}, 0);
        }
        for (const auto &s : sim.stars()) {
            const float cooling = 1 - smooth(0.12f, 0.95f, s.age / s.lifetime);
            const float fade = 1 - smooth(0.66f, 1.f, s.age / s.lifetime);
            const float scintillation = 0.78f + 0.22f * std::sin(s.age * 19 + s.phase);
            const float power = s.energy * fade * (1.05f + cooling * 2.1f);
            const auto tint = burnRgb(s.color, s.finalColor, s.colorMix());
            for (int j = 1; j < s.trailCount; ++j) {
                int newer = (s.trailHead - j + 1 + int(s.trail.size())) % int(s.trail.size());
                int older = (newer - 1 + int(s.trail.size())) % int(s.trail.size());
                const auto &a = s.trail[older], &b = s.trail[newer];
                float age = t - b.time;
                const float tailLife =
                    shell.trailLife +
                    (sim.shellType() == ShellType::Prismatic ? 0.5f : 0.15f) * std::sin(s.phase);
                if (age > tailLife)
                    continue;
                float f = std::pow(1 - age / tailLife, 1.7f);
                // Historical segments keep the burn color at emission time;
                // the tip changes to gold without recoloring the whole branch.
                const auto olderColor = burnRgb(s.color, s.finalColor, a.colorMix);
                const auto newerColor = burnRgb(s.color, s.finalColor, b.colorMix);
                Color ca{olderColor.r * power * f, olderColor.g * power * f, olderColor.b * power * f,
                         0.6f * f * fade};
                Color cb{newerColor.r * power * f, newerColor.g * power * f, newerColor.b * power * f,
                         0.6f * f * fade};
                line(project(a.position), project(b.position), shell.trailWidth * (0.70f + 0.45f * f) * scale,
                     ca * 0.90f, cb);
            }
            const auto p = project(s.position);
            quad(p, (1.65f + cooling * 0.55f) * std::sqrt(shell.trailWidth) * scale,
                 {tint.r * power * scintillation, tint.g * power * scintillation,
                  tint.b * power * scintillation, fade},
                 0);
        }
        for (const auto &e : sim.embers()) {
            const float age = e.age / e.lifetime;
            const float flicker = std::max(0.07f, 0.5f + 0.5f * std::sin(e.age * 53 + e.phase));
            const float fade = (1 - age) * (1 - age);
            const float power = e.energy * fade * (0.7f + flicker * 1.4f);
            const auto tint = burnRgb(e.color, e.finalColor, e.colorMix);
            quad(project(e.position), (1.15f + flicker * 0.55f) * scale,
                 {tint.r * power, tint.g * power, tint.b * power, fade * 0.8f}, 0);
        }
        if (sim.burst() && burstAge < 0.19f) {
            float flash = std::exp(-burstAge * 24.f);
            quad(project(sim.burstPosition()), (42.f + burstAge * 200.f) * scale,
                 {36 * flash, 38 * flash, 40 * flash, flash}, 3);
        }
    }

    bool makeScenePipeline(Owned<QRhiGraphicsPipeline> &p, bool additive) {
        p.reset(rhi->newGraphicsPipeline());
        p->setShaderStages({{QRhiShaderStage::Vertex, shader("scene.vert")},
                            {QRhiShaderStage::Fragment, shader("scene.frag")}});
        QRhiVertexInputLayout layout;
        layout.setBindings({{sizeof(Vertex)}});
        layout.setAttributes({{0, 0, QRhiVertexInputAttribute::Float2, 0},
                              {0, 1, QRhiVertexInputAttribute::Float2, 8},
                              {0, 2, QRhiVertexInputAttribute::Float4, 16},
                              {0, 3, QRhiVertexInputAttribute::Float4, 32}});
        p->setVertexInputLayout(layout);
        QRhiGraphicsPipeline::TargetBlend blend;
        blend.enable = true;
        blend.srcColor = QRhiGraphicsPipeline::One;
        blend.dstColor = additive ? QRhiGraphicsPipeline::One : QRhiGraphicsPipeline::OneMinusSrcAlpha;
        blend.srcAlpha = QRhiGraphicsPipeline::One;
        blend.dstAlpha = QRhiGraphicsPipeline::OneMinusSrcAlpha;
        p->setTargetBlends({blend});
        p->setShaderResourceBindings(sceneBindings.get());
        p->setRenderPassDescriptor(scene.pass.get());
        return p->create();
    }
    bool makePost(int index, QRhiTexture *source, QRhiRenderTarget *target, int mode, float dx, float dy) {
        auto &p = post[std::size_t(index)];
        p.target = target;
        p.mode = mode;
        p.dx = dx;
        p.dy = dy;
        p.uniforms.reset(rhi->newBuffer(QRhiBuffer::Dynamic, QRhiBuffer::UniformBuffer, 96));
        if (!p.uniforms->create())
            return false;
        p.bindings.reset(rhi->newShaderResourceBindings());
        p.bindings->setBindings(
            {QRhiShaderResourceBinding::uniformBuffer(
                 0, QRhiShaderResourceBinding::VertexStage | QRhiShaderResourceBinding::FragmentStage,
                 p.uniforms.get()),
             QRhiShaderResourceBinding::sampledTexture(1, QRhiShaderResourceBinding::FragmentStage, source,
                                                       sampler.get()),
             QRhiShaderResourceBinding::sampledTexture(2, QRhiShaderResourceBinding::FragmentStage,
                                                       mode == 2 ? halfA.texture.get() : source,
                                                       sampler.get()),
             QRhiShaderResourceBinding::sampledTexture(3, QRhiShaderResourceBinding::FragmentStage,
                                                       mode == 2 ? wideA.texture.get() : source,
                                                       sampler.get())});
        if (!p.bindings->create())
            return false;
        p.pipeline.reset(rhi->newGraphicsPipeline());
        p.pipeline->setShaderStages({{QRhiShaderStage::Vertex, shader("post.vert")},
                                     {QRhiShaderStage::Fragment, shader("post.frag")}});
        p.pipeline->setShaderResourceBindings(p.bindings.get());
        p.pipeline->setRenderPassDescriptor(target->renderPassDescriptor());
        p.pipeline->setSampleCount(target->sampleCount());
        return p.pipeline->create();
    }
};

Renderer::Renderer() : d(std::make_unique<Data>()) {}
Renderer::~Renderer() = default;
bool Renderer::initialize(QRhi *rhi, QRhiRenderTarget *output) {
    if (d->ready && d->rhi == rhi && d->output == output && d->size == output->pixelSize())
        return true;
    d = std::make_unique<Data>();
    d->rhi = rhi;
    d->output = output;
    d->size = output->pixelSize();
    if (d->size.isEmpty())
        return false;
    d->floating = rhi->isTextureFormatSupported(QRhiTexture::RGBA16F);
    auto format = d->floating ? QRhiTexture::RGBA16F : QRhiTexture::RGBA8;
    QSize half(std::max(1, d->size.width() / 2), std::max(1, d->size.height() / 2));
    QSize wide(std::max(1, d->size.width() / 4), std::max(1, d->size.height() / 4));
    if (!d->scene.create(rhi, d->size, format) || !d->halfA.create(rhi, half, format) ||
        !d->halfB.create(rhi, half, format) || !d->wideA.create(rhi, wide, format) ||
        !d->wideB.create(rhi, wide, format))
        return false;
    d->frame.reset(rhi->newBuffer(QRhiBuffer::Dynamic, QRhiBuffer::UniformBuffer, 80));
    d->bufferSize = 16 * 1024 * 1024;
    d->vertices.reset(rhi->newBuffer(QRhiBuffer::Dynamic, QRhiBuffer::VertexBuffer, quint32(d->bufferSize)));
    if (!d->frame->create() || !d->vertices->create())
        return false;
    d->geometry.reserve(180000);
    d->sampler.reset(rhi->newSampler(QRhiSampler::Linear, QRhiSampler::Linear, QRhiSampler::None,
                                     QRhiSampler::ClampToEdge, QRhiSampler::ClampToEdge));
    if (!d->sampler->create())
        return false;
    d->sceneBindings.reset(rhi->newShaderResourceBindings());
    d->sceneBindings->setBindings({QRhiShaderResourceBinding::uniformBuffer(
        0, QRhiShaderResourceBinding::VertexStage | QRhiShaderResourceBinding::FragmentStage,
        d->frame.get())});
    if (!d->sceneBindings->create() || !d->makeScenePipeline(d->lightPipeline, true) ||
        !d->makeScenePipeline(d->smokePipeline, false))
        return false;
    if (!d->makePost(0, d->scene.texture.get(), d->halfA.target.get(), 0, 1.f / d->size.width(),
                     1.f / d->size.height()) ||
        !d->makePost(1, d->halfA.texture.get(), d->halfB.target.get(), 1, 1.f / half.width(), 0) ||
        !d->makePost(2, d->halfB.texture.get(), d->halfA.target.get(), 1, 0, 1.f / half.height()) ||
        !d->makePost(3, d->halfA.texture.get(), d->wideA.target.get(), 3, 1.f / half.width(),
                     1.f / half.height()) ||
        !d->makePost(4, d->wideA.texture.get(), d->wideB.target.get(), 1, 2.f / wide.width(), 0) ||
        !d->makePost(5, d->wideB.texture.get(), d->wideA.target.get(), 1, 0, 2.f / wide.height()) ||
        !d->makePost(6, d->scene.texture.get(), output, 2, 0, 0))
        return false;
    d->ready = true;
    qInfo() << "Fireworks renderer:" << rhi->backendName() << rhi->driverInfo().deviceName << d->size << "HDR"
            << d->floating;
    return true;
}
void Renderer::render(QRhiCommandBuffer *cb, const Simulation &simulation, const RenderSettings &settings) {
    d->buildGeometry(simulation);
    if (d->geometry.size() * sizeof(Vertex) > d->bufferSize) {
        qWarning() << "Fireworks vertex budget exceeded";
        return;
    }
    auto *updates = d->rhi->nextResourceUpdateBatch();
    if (!d->geometry.empty())
        updates->updateDynamicBuffer(d->vertices.get(), 0, quint32(d->geometry.size() * sizeof(Vertex)),
                                     d->geometry.data());
    std::array<float, 20> frame{};
    auto matrix = d->rhi->clipSpaceCorrMatrix();
    std::memcpy(frame.data(), matrix.constData(), 64);
    frame[16] = float(d->size.width());
    frame[17] = float(d->size.height());
    frame[18] = float(simulation.time());
    updates->updateDynamicBuffer(d->frame.get(), 0, 80, frame.data());
    for (auto &p : d->post) {
        std::array<float, 24> data{};
        std::memcpy(data.data(), matrix.constData(), 64);
        data[16] = p.dx;
        data[17] = p.dy;
        data[18] = float(p.mode);
        data[19] = d->rhi->isYUpInFramebuffer() ? 0.f : 1.f;
        data[20] = settings.exposure;
        data[21] = settings.bloom;
        updates->updateDynamicBuffer(p.uniforms.get(), 0, 96, data.data());
    }
    cb->beginPass(d->scene.target.get(), Qt::transparent, {1, 0}, updates);
    cb->setViewport({0, 0, float(d->size.width()), float(d->size.height())});
    const QRhiCommandBuffer::VertexInput input(d->vertices.get(), 0);
    if (d->smokeVertices) {
        cb->setGraphicsPipeline(d->smokePipeline.get());
        cb->setViewport({0, 0, float(d->size.width()), float(d->size.height())});
        cb->setShaderResources();
        cb->setVertexInput(0, 1, &input);
        cb->draw(quint32(d->smokeVertices));
    }
    if (d->geometry.size() > d->smokeVertices) {
        cb->setGraphicsPipeline(d->lightPipeline.get());
        cb->setViewport({0, 0, float(d->size.width()), float(d->size.height())});
        cb->setShaderResources();
        cb->setVertexInput(0, 1, &input);
        cb->draw(quint32(d->geometry.size() - d->smokeVertices), 1, quint32(d->smokeVertices));
    }
    cb->endPass();
    for (auto &p : d->post) {
        cb->beginPass(p.target, Qt::transparent, {1, 0});
        cb->setGraphicsPipeline(p.pipeline.get());
        cb->setShaderResources();
        cb->setViewport({0, 0, float(p.target->pixelSize().width()), float(p.target->pixelSize().height())});
        cb->draw(3);
        cb->endPass();
    }
}
bool Renderer::hdr() const { return d->floating; }
std::size_t Renderer::vertexCount() const { return d->geometry.size(); }
QRhiTexture *Renderer::diagnosticTexture(int stage) const {
    if (stage == 0)
        return d->scene.texture.get();
    if (stage == 1)
        return d->halfA.texture.get();
    return d->wideA.texture.get();
}
} // namespace fireworks
