#pragma once
#include "shell.h"
#include <QByteArray>
#include <cstdint>

namespace fireworks {
// Deterministic stereo PCM. Precomputed off the audio callback; bounded and reusable.
// `bias` leans the stereo image towards the side the shell was launched from,
// normalised to [-1, 1]: a shell that goes up on the left should not boom from
// the middle.
QByteArray synthesizeShow(std::uint32_t seed, int sampleRate = 48000,
                          ShellType shell = ShellType::Chrysanthemum, float bias = 0);
QByteArray waveFile(const QByteArray &pcm, int sampleRate = 48000);
} // namespace fireworks
