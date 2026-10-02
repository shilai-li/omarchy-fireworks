#include "audio.h"
#include "renderer.h"
#include <QCommandLineParser>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QVulkanInstance>
#include <algorithm>
#include <array>
#include <cmath>
#include <memory>
#include <qfloat16.h>
#include <rhi/qrhi.h>

int main(int argc, char **argv) {
    // Use the desktop's platform Vulkan integration, but create no visible window.
    // Qt's offscreen QPA plugin cannot create a platform Vulkan instance.
    qputenv("QT_FORCE_STDERR_LOGGING", "1");
    QGuiApplication app(argc, argv);
    QCommandLineParser parser;
    parser.addHelpOption();
    parser.addPositionalArgument("folder", "Capture output directory", "[folder]");
    QStringList slugs;
    for (const auto &shell : fireworks::Shells)
        slugs.append(QString::fromUtf8(shell.slug));
    parser.addOption({"shell", "One of: " + slugs.join(", "), "name", "chrysanthemum"});
    parser.addOption({"launch", "Launch position across the frame, -1 to 1", "x", "0"});
    parser.addOption({"sequence", "Capture the full 30 fps sequence"});
    parser.addOption({"diagnostics", "Print internal texture diagnostics"});
    parser.process(app);
    const int selected = fireworks::shellIndex(parser.value("shell").toStdString());
    if (selected < 0 || parser.positionalArguments().size() > 1) {
        qCritical() << "Invalid shell or capture arguments";
        return 2;
    }
    bool launchOk = false;
    const float launchX = parser.value("launch").toFloat(&launchOk);
    if (!launchOk || !std::isfinite(launchX) || launchX < -1 || launchX > 1) {
        qCritical() << "Launch position must be a number from -1 to 1";
        return 2;
    }
    const float originX = launchX * fireworks::LaunchSpread;
    const auto shellType = fireworks::ShellType(selected);
    const auto &shell = fireworks::shellDefinition(shellType);
    const bool diagnostics = parser.isSet("diagnostics");
    QString folder = parser.positionalArguments().isEmpty() ? QStringLiteral("artifacts")
                                                            : parser.positionalArguments().first();
    if (!QDir().mkpath(folder)) {
        qCritical() << "Cannot create capture directory" << folder;
        return 1;
    }
    QVulkanInstance instance;
    instance.setExtensions(QRhiVulkanInitParams::preferredInstanceExtensions());
    if (!instance.create()) {
        qCritical() << "Cannot initialize Vulkan";
        return 1;
    }
    QRhiVulkanInitParams params;
    params.inst = &instance;
    std::unique_ptr<QRhi> rhi(QRhi::create(QRhi::Vulkan, &params, QRhi::EnableTimestamps));
    if (!rhi) {
        qCritical() << "Cannot create a Vulkan rendering device";
        return 1;
    }
    const QSize size(1920, 1080);
    std::unique_ptr<QRhiTexture> texture(rhi->newTexture(
        QRhiTexture::RGBA8, size, 1, QRhiTexture::RenderTarget | QRhiTexture::UsedAsTransferSource));
    if (!texture->create())
        return 1;
    std::unique_ptr<QRhiTextureRenderTarget> target(
        rhi->newTextureRenderTarget(QRhiTextureRenderTargetDescription(QRhiColorAttachment(texture.get()))));
    std::unique_ptr<QRhiRenderPassDescriptor> descriptor(target->newCompatibleRenderPassDescriptor());
    target->setRenderPassDescriptor(descriptor.get());
    if (!target->create())
        return 1;
    fireworks::Renderer renderer;
    if (!renderer.initialize(rhi.get(), target.get()))
        return 1;
    fireworks::Simulation simulation(73, shellType);
    simulation.setOrigin(originX);
    QJsonArray results;
    std::array<double, 6> times{1.15, 2.03, shell.heroTime, shell.fallTime, shell.decayTime, 11.0};
    QImage contact(1280, 1170, QImage::Format_RGB32);
    contact.fill(QColor("#090c12"));
    QPainter contactPainter(&contact);
    for (std::size_t i = 0; i < times.size(); ++i) {
        simulation.advanceTo(times[i]);
        QRhiCommandBuffer *cb = nullptr;
        if (rhi->beginOffscreenFrame(&cb) != QRhi::FrameOpSuccess)
            return 1;
        QElapsedTimer elapsed;
        elapsed.start();
        renderer.render(cb, simulation, {});
        QRhiReadbackResult readback;
        std::array<QRhiReadbackResult, 3> stages;
        auto *batch = rhi->nextResourceUpdateBatch();
        batch->readBackTexture(QRhiReadbackDescription(texture.get()), &readback);
        if (diagnostics)
            for (int stage = 0; stage < 3; ++stage)
                batch->readBackTexture(QRhiReadbackDescription(renderer.diagnosticTexture(stage)),
                                       &stages[stage]);
        cb->resourceUpdate(batch);
        if (rhi->endOffscreenFrame() != QRhi::FrameOpSuccess)
            return 1;
        rhi->finish();
        if (diagnostics)
            for (int stage = 0; stage < 3; ++stage) {
                float maximum = 0;
                const auto *values = reinterpret_cast<const qfloat16 *>(stages[stage].data.constData());
                for (qsizetype n = 0; n < stages[stage].data.size() / 2; ++n)
                    maximum = std::max(maximum, float(values[n]));
                qInfo() << "stage" << stage << "max" << maximum << "bytes" << stages[stage].data.size()
                        << "vertices" << renderer.vertexCount();
            }
        const double milliseconds = elapsed.nsecsElapsed() / 1e6;
        if (readback.data.size() != size.width() * size.height() * 4) {
            qCritical() << "Invalid readback";
            return 1;
        }
        QImage frame(reinterpret_cast<const uchar *>(readback.data.constData()), size.width(), size.height(),
                     QImage::Format_RGBA8888_Premultiplied);
        if (rhi->isYUpInFramebuffer())
#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
            frame = frame.flipped(Qt::Vertical);
#else
            frame = frame.mirrored(false, true);
#endif
        else
            frame = frame.copy();
        int covered = 0, nonTransparent = 0, invalid = 0;
        std::array<int, 6> huePixels{};
        for (int y = 0; y < frame.height(); ++y) {
            const auto *pixels = frame.constScanLine(y);
            for (int x = 0; x < frame.width(); ++x) {
                const auto *p = pixels + x * 4;
                if (p[3] > 8)
                    ++covered;
                if (p[3] != 0)
                    ++nonTransparent;
                if (p[0] > p[3] + 1 || p[1] > p[3] + 1 || p[2] > p[3] + 1)
                    ++invalid;
                const float peak = std::max({p[0], p[1], p[2]});
                const float chroma = peak - std::min({p[0], p[1], p[2]});
                // Six 60-degree hue sectors, excluding dim pixels and pale
                // spark cores. A monochrome or washed-out render must fail.
                if (peak > 64 && chroma > peak * 0.4f) {
                    float hue = peak == p[0]   ? (float(p[1]) - p[2]) / chroma
                                : peak == p[1] ? (float(p[2]) - p[0]) / chroma + 2
                                               : (float(p[0]) - p[1]) / chroma + 4;
                    if (hue < 0)
                        hue += 6;
                    ++huePixels[std::size_t(std::clamp(int(hue), 0, 5))];
                }
            }
        }
        if (invalid || (times[i] < 9 && covered < 20) || (times[i] == 11 && nonTransparent != 0)) {
            qCritical() << "Frame validation failed:" << times[i] << "coverage" << covered << "invalid alpha"
                        << invalid;
            return 1;
        }
        if (shell.multicolor && (i == 2 || i == 3) &&
            *std::min_element(huePixels.begin(), huePixels.end()) < 100) {
            qCritical() << "Color validation failed: burst and falling trails must span all six hue sectors";
            return 1;
        }
        if (i == 2 && std::count_if(huePixels.begin(), huePixels.end(), [](int n) { return n >= 100; }) < 2) {
            qCritical() << "Color validation failed: authored shell must retain warm/cool color separation";
            return 1;
        }
        QJsonArray hues;
        for (int count : huePixels)
            hues.append(count);
        const QString stem = QStringLiteral("%1-%2s").arg(i + 1, 2, 10, QChar('0')).arg(times[i], 0, 'f', 2);
        if (!frame.save(folder + "/" + stem + "-transparent.png"))
            return 1;
        QImage dark(size, QImage::Format_RGB32);
        dark.fill(QColor("#080b11"));
        {
            QPainter painter(&dark);
            painter.drawImage(0, 0, frame);
        }
        dark.save(folder + "/" + stem + ".png");
        if (i == 2) {
            QImage light(size, QImage::Format_RGB32);
            light.fill(QColor("#eeeeef"));
            {
                QPainter painter(&light);
                painter.drawImage(0, 0, frame);
            }
            light.save(folder + "/light-background.png");
        }
        const int cx = int(i % 2) * 640, cy = int(i / 2) * 390;
        contactPainter.drawImage(QRect(cx, cy, 640, 360), dark);
        contactPainter.setPen(QColor("#c9b596"));
        contactPainter.drawText(cx + 18, cy + 379,
                                QString("%1 s  ·  %2 stars  ·  %3 embers")
                                    .arg(times[i], 0, 'f', 2)
                                    .arg(simulation.stars().size())
                                    .arg(simulation.embers().size()));
        results.append(QJsonObject{{"time", times[i]},
                                   {"coveredPixels", covered},
                                   {"nonTransparentPixels", nonTransparent},
                                   {"invalidPremultipliedPixels", invalid},
                                   {"saturatedHuePixels", hues},
                                   {"vertices", double(renderer.vertexCount())},
                                   {"renderAndReadbackMs", milliseconds}});
        qInfo() << stem << "coverage" << covered << "vertices" << renderer.vertexCount()
                << "render+readback ms" << milliseconds;
    }
    contactPainter.end();
    contact.save(folder + "/contact-sheet.png");
    if (parser.isSet("sequence")) {
        const auto sequenceFolder = folder + "/sequence";
        if (!QDir().mkpath(sequenceFolder))
            return 1;
        fireworks::Simulation movie(73, shellType);
        movie.setOrigin(originX);
        for (int index = 0; index <= 330; ++index) {
            movie.advanceTo(index / 30.0);
            QRhiCommandBuffer *cb = nullptr;
            if (rhi->beginOffscreenFrame(&cb) != QRhi::FrameOpSuccess)
                return 1;
            renderer.render(cb, movie, {});
            QRhiReadbackResult readback;
            auto *batch = rhi->nextResourceUpdateBatch();
            batch->readBackTexture(QRhiReadbackDescription(texture.get()), &readback);
            cb->resourceUpdate(batch);
            if (rhi->endOffscreenFrame() != QRhi::FrameOpSuccess)
                return 1;
            rhi->finish();
            if (readback.data.size() != size.width() * size.height() * 4)
                return 1;
            QImage frame(reinterpret_cast<const uchar *>(readback.data.constData()), size.width(),
                         size.height(), QImage::Format_RGBA8888_Premultiplied);
            QImage dark(size, QImage::Format_RGB32);
            dark.fill(QColor("#080b11"));
            {
                QPainter painter(&dark);
                painter.drawImage(0, 0, frame);
            }
            if (!dark.save(sequenceFolder + QString("/frame-%1.png").arg(index, 4, 10, QChar('0'))))
                return 1;
            if (index % 60 == 0)
                qInfo() << "Animation capture" << index << "/ 330";
        }
    }
    QFile audio(folder + "/show.wav");
    if (!audio.open(QIODevice::WriteOnly))
        return 1;
    audio.write(fireworks::waveFile(fireworks::synthesizeShow(73, 48000, shellType, launchX)));
    audio.close();
    QFile report(folder + "/verification.json");
    if (!report.open(QIODevice::WriteOnly))
        return 1;
    report.write(
        QJsonDocument(
            QJsonObject{{"effect", QString::fromUtf8(shell.name)},
                        {"shell", QString::fromUtf8(shell.slug)},
                        {"backend", QString::fromLatin1(rhi->backendName())},
                        {"device", QString::fromUtf8(rhi->driverInfo().deviceName)},
                        {"hdr", renderer.hdr()},
                        {"width", size.width()},
                        {"height", size.height()},
                        {"seed", 73},
                        {"frames", results},
                        {"timingNote",
                         "Includes GPU completion and readback; not an interactive frame-rate benchmark."}})
            .toJson());
    return 0;
}
