#pragma once
#include "palette.h"
#include <string_view>

namespace fireworks {
enum class ShellType { Chrysanthemum, Palm, Willow, Prismatic };
struct ShellDefinition {
    const char *slug;
    const char *name;
    const char *description;
    int stars = 460;
    float speedMin = 56, speedMax = 82;
    float lifeMin = 4.8f, lifeMax = 7.5f;
    float drag = 0.41f, trailLife = 1.7f, trailWidth = 1;
    float sheddingInterval = 0.045f;
    int sheddingCount = 1;
    SparkColor primary = SparkColor::Violet, secondary = SparkColor::Cyan;
    float transitionStart = 0.56f, transitionEnd = 0.88f;
    float crackleStart = 2.4f, crackleEnd = 6.0f;
    int audioCrackles = 85;
    double heroTime = 3.7, fallTime = 5.9, decayTime = 8.2;
};
inline constexpr std::array<ShellDefinition, 4> Shells{{
    {.slug = "chrysanthemum",
     .name = "Crimson chrysanthemum",
     .description = "A crimson sphere, a cyan heart, and gold-changing tips.",
     .stars = 360,
     .speedMin = 70,
     .speedMax = 94,
     .lifeMin = 3.2f,
     .lifeMax = 4.1f,
     .drag = 0.62f,
     .trailLife = 0.80f,
     .trailWidth = 1.0f,
     .primary = SparkColor::Ruby,
     .secondary = SparkColor::Cyan,
     .transitionStart = 0.40f,
     .transitionEnd = 0.76f,
     .crackleStart = 1.9f,
     .crackleEnd = 3.7f,
     .audioCrackles = 65,
     .heroTime = 3.0,
     .fallTime = 4.3,
     .decayTime = 5.7},
    {.slug = "palm",
     .name = "Emerald palm",
     .description = "Twelve emerald and cyan fronds arch into a gold finish.",
     .stars = 96,
     .speedMin = 66,
     .speedMax = 84,
     .lifeMin = 4.4f,
     .lifeMax = 5.4f,
     .drag = 0.23f,
     .trailLife = 2.10f,
     .trailWidth = 1.65f,
     .sheddingInterval = 0.035f,
     .sheddingCount = 3,
     .primary = SparkColor::Emerald,
     .secondary = SparkColor::Cyan,
     .transitionStart = 0.52f,
     .transitionEnd = 0.86f,
     .crackleStart = 2.7f,
     .crackleEnd = 5.1f,
     .audioCrackles = 95,
     .heroTime = 3.7,
     .fallTime = 5.3,
     .decayTime = 7.0},
    {.slug = "willow",
     .name = "Violet willow",
     .description = "Violet and ice-blue branches linger, then dissolve into gold.",
     .stars = 420,
     .speedMin = 56,
     .speedMax = 78,
     .lifeMin = 5.0f,
     .lifeMax = 7.2f,
     .drag = 0.38f,
     .trailLife = 2.15f,
     .trailWidth = 0.90f,
     .primary = SparkColor::Violet,
     .secondary = SparkColor::Cyan,
     .transitionStart = 0.48f,
     .transitionEnd = 0.80f,
     .crackleStart = 3.9f,
     .crackleEnd = 6.6f,
     .audioCrackles = 110,
     .heroTime = 3.7,
     .fallTime = 6.2,
     .decayTime = 8.5},
    {.slug = "prismatic",
     .name = "Prismatic willow",
     .description = "The original eight-color willow, with a lingering afterglow.",
     .transitionStart = 2,
     .transitionEnd = 3,
     .crackleStart = 1.4f,
     .crackleEnd = 5.264f},
}};
constexpr const ShellDefinition &shellDefinition(ShellType type) { return Shells[std::size_t(type)]; }
constexpr int shellIndex(std::string_view slug) {
    for (std::size_t i = 0; i < Shells.size(); ++i)
        if (slug == Shells[i].slug)
            return int(i);
    return -1;
}
} // namespace fireworks
