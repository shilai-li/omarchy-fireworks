#include "audio.h"
#include "simulation.h"
#include <QtEndian>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace fireworks {
QByteArray synthesizeShow(std::uint32_t seed, int sampleRate, ShellType shellType) {
    if (sampleRate < 8000 || sampleRate > 192000 || int(shellType) < 0 ||
        std::size_t(shellType) >= Shells.size())
        return {};
    const int frames = int(Simulation::Duration * sampleRate);
    std::vector<float> mix(std::size_t(frames) * 2, 0);
    std::uint32_t state = seed ? seed : 1;
    auto noise = [&]() {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return float(state >> 8) / 8388608.f - 1.f;
    };
    auto voice = [&](double start, double duration, float gain, float pan, bool boom) {
        const int first = int(start * sampleRate), count = int(duration * sampleRate);
        const float left = std::sqrt((1 - pan) * 0.5f), right = std::sqrt((1 + pan) * 0.5f);
        float low = 0;
        for (int j = 0; j < count && first + j < frames; ++j) {
            if (first + j < 0)
                continue;
            const float t = float(j) / sampleRate;
            const float n = noise();
            low += (boom ? 0.012f : 0.21f) * (n - low);
            const float attack = 1 - std::exp(-t * (boom ? 1100.f : 2300.f));
            const float envelope = attack * std::exp(-t / (boom ? 0.58f : 0.035f));
            const float signal =
                boom ? low * 2.5f +
                           0.22f * std::sin(6.283185f * (47.f * t + 7.f * (1 - std::exp(-t * 6.f)))) *
                               std::exp(-t * 2.f) +
                           n * 0.12f * std::exp(-t * 35.f)
                     : (n - low * 0.7f) * 0.65f;
            const float value = gain * signal * envelope;
            mix[std::size_t(first + j) * 2] += value * left;
            mix[std::size_t(first + j) * 2 + 1] += value * right;
        }
    };
    // A fictional listener 120 metres away: sound follows the visible burst.
    const double delay = 120.0 / 343.0;
    voice(Simulation::BurstTime + delay, 3.4, 0.9f, -0.08f, true);
    voice(Simulation::BurstTime + delay + 0.19, 2.4, 0.24f, 0.25f, true);
    const auto &shell = shellDefinition(shellType);
    for (int i = 0; i < shell.audioCrackles; ++i) {
        const float jitter = (noise() + 1) * 0.5f;
        const float pan = noise() * 0.8f;
        voice(Simulation::BurstTime + delay + shell.crackleStart +
                  i * (shell.crackleEnd - shell.crackleStart) / (shell.audioCrackles - 1) + jitter * 0.09,
              0.19, 0.035f + jitter * 0.07f, pan, false);
    }
    QByteArray pcm(frames * 4, Qt::Uninitialized);
    for (std::size_t i = 0; i < mix.size(); ++i) {
        const auto value = qint16(std::lround(std::tanh(mix[i]) * 26000));
        qToLittleEndian<qint16>(value, reinterpret_cast<uchar *>(pcm.data()) + i * 2);
    }
    return pcm;
}
QByteArray waveFile(const QByteArray &pcm, int sampleRate) {
    QByteArray out(44, 0);
    std::memcpy(out.data(), "RIFF", 4);
    std::memcpy(out.data() + 8, "WAVEfmt ", 8);
    auto u32 = [&](int at, quint32 v) { qToLittleEndian(v, reinterpret_cast<uchar *>(out.data() + at)); };
    auto u16 = [&](int at, quint16 v) { qToLittleEndian(v, reinterpret_cast<uchar *>(out.data() + at)); };
    u32(4, quint32(pcm.size() + 36));
    u32(16, 16);
    u16(20, 1);
    u16(22, 2);
    u32(24, sampleRate);
    u32(28, sampleRate * 4);
    u16(32, 4);
    u16(34, 16);
    std::memcpy(out.data() + 36, "data", 4);
    u32(40, quint32(pcm.size()));
    out += pcm;
    return out;
}
} // namespace fireworks
