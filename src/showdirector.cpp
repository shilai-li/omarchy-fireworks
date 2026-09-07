#include "showdirector.h"
#include "audio.h"
#include "simulation.h"
#include <QMediaDevices>
#include <QtConcurrentRun>
#include <algorithm>
#include <cmath>

ShowDirector::ShowDirector(QObject *parent) : QObject(parent) {
    m_timer.setTimerType(Qt::PreciseTimer);
    m_timer.setInterval(8);
    connect(&m_timer, &QTimer::timeout, this, [this] {
        m_time = std::min(duration(), m_base + m_clock.nsecsElapsed() / 1e9);
        emit timeChanged();
        if (m_time >= duration()) {
            pause();
            emit finished();
        }
    });
    connect(&m_preparation, &QFutureWatcher<QByteArray>::finished, this, [this] {
        m_pcm = m_preparation.result();
        m_readySeed = m_preparingSeed;
        m_readyShell = m_preparingShell;
        if (m_readySeed != m_seed || m_readyShell != m_shellType) {
            prepareAudio();
            return;
        }
        if (m_running && m_audioEnabled)
            startAudio();
    });
}
ShowDirector::~ShowDirector() { stopAudio(); }
double ShowDirector::duration() const { return fireworks::Simulation::Duration; }
QStringList ShowDirector::shellNames() const {
    QStringList result;
    for (const auto &shell : fireworks::Shells)
        result.append(QString::fromUtf8(shell.name));
    return result;
}
QString ShowDirector::shellName() const { return QString::fromUtf8(fireworks::Shells[m_shellType].name); }
QString ShowDirector::shellDescription() const {
    return QString::fromUtf8(fireworks::Shells[m_shellType].description);
}
double ShowDirector::previewTime() const { return fireworks::Shells[m_shellType].heroTime; }
int ShowDirector::shellIndex(const QString &slug) const { return fireworks::shellIndex(slug.toStdString()); }
void ShowDirector::setShellType(int type) {
    type = std::clamp(type, 0, int(fireworks::Shells.size()) - 1);
    if (m_shellType == type)
        return;
    m_shellType = type;
    emit shellTypeChanged();
    if (m_running && m_audioEnabled) {
        stopAudio();
        prepareAudio();
    }
}
void ShowDirector::setSeed(int seed) {
    if (m_seed == seed)
        return;
    m_seed = seed;
    emit seedChanged();
    if (m_running && m_audioEnabled) {
        stopAudio();
        prepareAudio();
    }
}
void ShowDirector::setAudioEnabled(bool value) {
    if (m_audioEnabled == value)
        return;
    m_audioEnabled = value;
    emit audioEnabledChanged();
    if (!value)
        stopAudio();
    else if (m_running)
        prepareAudio();
}
void ShowDirector::setVolume(float value) {
    if (!std::isfinite(value))
        return;
    value = std::clamp(value, 0.f, 1.f);
    if (m_volume == value)
        return;
    m_volume = value;
    if (m_sink)
        m_sink->setVolume(value);
    emit volumeChanged();
}
void ShowDirector::launch() {
    pause();
    m_time = 0;
    emit timeChanged();
    resume();
}
void ShowDirector::pause() {
    m_timer.stop();
    stopAudio();
    if (!m_running)
        return;
    m_running = false;
    emit runningChanged();
}
void ShowDirector::resume() {
    if (m_running)
        return;
    if (m_time >= duration()) {
        m_time = 0;
        emit timeChanged();
    }
    m_base = m_time;
    m_clock.restart();
    m_running = true;
    emit runningChanged();
    m_timer.start();
    if (m_audioEnabled)
        prepareAudio();
}
void ShowDirector::seek(double time) {
    if (!std::isfinite(time))
        return;
    pause();
    m_time = std::clamp(time, 0.0, duration());
    emit timeChanged();
}
void ShowDirector::prepareAudio() {
    if (m_readySeed == m_seed && m_readyShell == m_shellType) {
        startAudio();
        return;
    }
    if (m_preparation.isRunning())
        return;
    m_preparingSeed = m_seed;
    m_preparingShell = m_shellType;
    const auto seed = std::uint32_t(m_seed);
    const auto shell = fireworks::ShellType(m_shellType);
    m_preparation.setFuture(
        QtConcurrent::run([seed, shell] { return fireworks::synthesizeShow(seed, 48000, shell); }));
}
void ShowDirector::startAudio() {
    stopAudio();
    const auto device = QMediaDevices::defaultAudioOutput();
    if (device.isNull() || !m_running || !m_audioEnabled)
        return;
    QAudioFormat format;
    format.setSampleRate(48000);
    format.setChannelCount(2);
    format.setSampleFormat(QAudioFormat::Int16);
    if (!device.isFormatSupported(format)) {
        qWarning() << "Fireworks: output does not support 48 kHz stereo PCM";
        return;
    }
    m_buffer.setData(m_pcm);
    m_buffer.open(QIODevice::ReadOnly);
    const double now = m_base + m_clock.nsecsElapsed() / 1e9;
    m_buffer.seek(std::min(qint64(now * 48000) * 4, qint64(m_pcm.size())));
    m_sink = std::make_unique<QAudioSink>(device, format);
    m_sink->setBufferSize(4800 * 4);
    m_sink->setVolume(m_volume);
    m_sink->start(&m_buffer);
}
void ShowDirector::stopAudio() {
    if (m_sink) {
        m_sink->stop();
        m_sink.reset();
    }
    m_buffer.close();
}
