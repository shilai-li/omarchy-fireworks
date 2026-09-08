#pragma once
#include "palette.h"
#include <string_view>

namespace fireworks {
// The plane the ring shell is thrown in, tilted away from the camera so it
// reads as a ring in perspective rather than as a flat circle. Shared with the
// tests, which check the ring stays planar and would otherwise carry their own
// copy of these numbers and quietly drift from them.
inline constexpr float RingTiltCos = 0.40f, RingTiltSin = 0.92f;
// Appended, never reordered: the plugin stores the selected shell as an index.
enum class ShellType { Chrysanthemum, Palm, Willow, Prismatic, Ring, Peony, Crossette };
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
    // Crossette breaking: a star reaching this fraction of its life is replaced
    // by `splitInto` children thrown perpendicular to its flight at
    // `splitSpeed`. Zero leaves the shell unsplit, which is every other shell.
    float splitAt = 0;
    int splitInto = 0;
    float splitSpeed = 0;
    double heroTime = 3.7, fallTime = 5.9, decayTime = 8.2;
};
inline constexpr std::array<ShellDefinition, 7> Shells{{
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
    {.slug = "ring",
     .name = "Sapphire ring",
     .description = "A tilted sapphire ring banded with rose, hanging before it falls.",
     .stars = 300,
     .speedMin = 74,
     .speedMax = 80,
     .lifeMin = 3.6f,
     .lifeMax = 4.4f,
     .drag = 0.42f,
     // Short tails on purpose: at the willow's 1.7s every trail reaches back to
     // the burst and the ring fills in as a disc. The ring has to stay hollow.
     .trailLife = 0.30f,
     .trailWidth = 1.35f,
     .sheddingInterval = 0.09f,
     .primary = SparkColor::Sapphire,
     .secondary = SparkColor::Rose,
     .transitionStart = 0.58f,
     .transitionEnd = 0.90f,
     .crackleStart = 2.2f,
     .crackleEnd = 4.1f,
     .audioCrackles = 74,
     .heroTime = 3.2,
     .fallTime = 4.6,
     .decayTime = 6.2},
    {.slug = "peony",
     .name = "Rose peony",
     .description = "Three nested rose and sapphire layers fade one after another.",
     .stars = 390,
     .speedMin = 64,
     .speedMax = 88,
     .lifeMin = 3.8f,
     .lifeMax = 4.8f,
     .drag = 0.55f,
     .trailLife = 0.95f,
     .trailWidth = 1.05f,
     .sheddingInterval = 0.05f,
     .primary = SparkColor::Rose,
     .secondary = SparkColor::Sapphire,
     .transitionStart = 0.46f,
     .transitionEnd = 0.82f,
     .crackleStart = 2.1f,
     .crackleEnd = 5.4f,
     .audioCrackles = 88,
     .heroTime = 3.4,
     .fallTime = 5.0,
     .decayTime = 6.8},
    {.slug = "crossette",
     .name = "Lime crossette",
     .description = "Few heavy stars fly out, then each breaks into a bright cross.",
     .stars = 72,
     .speedMin = 52,
     .speedMax = 64,
     .lifeMin = 4.6f,
     .lifeMax = 5.4f,
     .drag = 0.30f,
     .trailLife = 1.45f,
     .trailWidth = 1.45f,
     .sheddingInterval = 0.05f,
     .sheddingCount = 2,
     .primary = SparkColor::Lime,
     .secondary = SparkColor::Cyan,
     .transitionStart = 0.62f,
     .transitionEnd = 0.92f,
     // A crossette child is born when its parent breaks, with its age back at
     // zero, so this window is measured from the break and not from the burst.
     // The willow's 3.9s would land after every child is already dead.
     .crackleStart = 1.1f,
     .crackleEnd = 3.2f,
     .audioCrackles = 128,
     .splitAt = 0.34f,
     .splitInto = 4,
     .splitSpeed = 26.f,
     .heroTime = 4.1,
     .fallTime = 5.6,
     .decayTime = 7.4},
}};
constexpr const ShellDefinition &shellDefinition(ShellType type) { return Shells[std::size_t(type)]; }
constexpr int shellIndex(std::string_view slug) {
    for (std::size_t i = 0; i < Shells.size(); ++i)
        if (slug == Shells[i].slug)
            return int(i);
    return -1;
}
} // namespace fireworks
