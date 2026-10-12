#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace fireworks {
// An authored star composition, not a time-varying rainbow filter. Children
// inherit this identity so each branch keeps its color as it sheds sparks.
enum class SparkColor : std::uint8_t { Ruby, Amber, Lime, Emerald, Cyan, Sapphire, Violet, Rose };
struct LinearRgb {
    float r, g, b;
};
inline constexpr std::array<LinearRgb, 8> SparkPalette{{
    {1.00f, 0.018f, 0.065f}, // ruby
    {1.00f, 0.460f, 0.018f}, // amber
    {0.48f, 1.000f, 0.025f}, // lime
    {0.02f, 1.000f, 0.220f}, // emerald
    {0.02f, 0.780f, 1.000f}, // cyan
    {0.06f, 0.180f, 1.000f}, // sapphire
    {0.46f, 0.035f, 1.000f}, // violet
    {1.00f, 0.025f, 0.470f}, // rose
}};
constexpr LinearRgb sparkRgb(SparkColor color) { return SparkPalette[std::size_t(color)]; }
constexpr LinearRgb burnRgb(SparkColor initial, SparkColor final, float mix) {
    const auto a = sparkRgb(initial), b = sparkRgb(final);
    return {a.r + (b.r - a.r) * mix, a.g + (b.g - a.g) * mix, a.b + (b.b - a.b) * mix};
}
constexpr SparkColor prismaticColor(std::size_t index, std::uint32_t seed) {
    // Interleave warm and cool stars around the shell without consuming the
    // physics PRNG or changing trajectories when the palette is edited.
    return SparkColor((index * 5 + seed % SparkPalette.size()) % SparkPalette.size());
}
} // namespace fireworks
