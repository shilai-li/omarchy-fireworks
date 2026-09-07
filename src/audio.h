#pragma once
#include "shell.h"
#include <QByteArray>
#include <cstdint>

namespace fireworks {
// Deterministic stereo PCM. Precomputed off the audio callback; bounded and reusable.
QByteArray synthesizeShow(std::uint32_t seed, int sampleRate = 48000,
                          ShellType shell = ShellType::Chrysanthemum);
QByteArray waveFile(const QByteArray &pcm, int sampleRate = 48000);
} // namespace fireworks
