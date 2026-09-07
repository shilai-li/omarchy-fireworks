#include "audio.h"
#include "simulation.h"
#include <QtEndian>
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>

void require(bool result, const char *message) {
    if (!result) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}
bool same(fireworks::Vec3 a, fireworks::Vec3 b) { return a.x == b.x && a.y == b.y && a.z == b.z; }
int main() {
    using fireworks::Simulation;
    Simulation one(73, fireworks::ShellType::Prismatic), many(73, fireworks::ShellType::Prismatic);
    one.advanceTo(1.9);
    require(!one.burst() && one.stars().empty(), "rocket must precede the explosion");
    require(one.rocket().y > 120, "rocket must ascend above the launch point");
    one.advanceTo(3.7);
    for (int i = 1; i <= 444; ++i)
        many.advanceTo(i * Simulation::Step);
    require(one.burst() && one.stars().size() == 460, "spherical burst must contain the authored stars");
    require(one.stars().size() == many.stars().size() && one.embers().size() == many.embers().size(),
            "frame pacing must not change population");
    std::array<int, fireworks::SparkPalette.size()> starColors{}, emberColors{};
    for (std::size_t i = 0; i < one.stars().size(); ++i) {
        require(same(one.stars()[i].position, many.stars()[i].position),
                "fixed steps must produce identical positions");
        require(one.stars()[i].trailCount > 20, "willow must preserve trail history");
        const auto color = one.stars()[i].color;
        require(color == fireworks::prismaticColor(i, 73) && color == many.stars()[i].color,
                "star colors must be authored and independent of frame pacing");
        ++starColors[std::size_t(color)];
    }
    for (std::size_t i = 0; i < one.embers().size(); ++i) {
        const auto color = one.embers()[i].color;
        require(std::size_t(color) < fireworks::SparkPalette.size() && color == many.embers()[i].color,
                "shed spark colors must remain valid and deterministic");
        ++emberColors[std::size_t(color)];
    }
    for (std::size_t i = 0; i < fireworks::SparkPalette.size(); ++i) {
        require(starColors[i] >= 50 && emberColors[i] > 100,
                "both branches and their embers must represent the full palette");
        const auto rgb = fireworks::SparkPalette[i];
        require(std::min({rgb.r, rgb.g, rgb.b}) >= 0 && std::max({rgb.r, rgb.g, rgb.b}) == 1,
                "palette colors must be normalized nonnegative radiance");
    }
    auto bounds = std::minmax_element(one.stars().begin(), one.stars().end(),
                                      [](auto &a, auto &b) { return a.position.z < b.position.z; });
    require(bounds.second->position.z - bounds.first->position.z > 100, "burst must have real depth");
    auto saved = one.stars()[30].position;
    one.advanceTo(0.5);
    one.advanceTo(3.7);
    require(same(saved, one.stars()[30].position), "rewinding must reconstruct the same seeded show");
    for (std::size_t i = 0; i < one.stars().size(); ++i)
        require(one.stars()[i].color == many.stars()[i].color, "rewinding must preserve branch colors");
    Simulation windy(73, fireworks::ShellType::Prismatic);
    windy.setWind(12);
    windy.advanceTo(3.7);
    require(windy.stars()[30].position.x > saved.x, "wind must influence star trajectories");
    Simulation limited;
    limited.advanceTo(11, 12);
    require(limited.time() < 0.11, "render-thread catch-up must be bounded");
    limited.advanceTo(std::numeric_limits<double>::infinity());
    require(limited.time() < 0.11, "non-finite input must not hang simulation");
    one.advanceTo(6.5);
    require(!one.stars().empty() && !one.smoke().empty(), "willow must have a lingering tail");
    for (const auto &s : one.stars())
        require(s.velocity.y < 0, "late willow branches must fall under gravity");
    require(one.embers().size() <= Simulation::MaxEmbers && one.smoke().size() <= Simulation::MaxSmoke,
            "populations must remain bounded");
    one.advanceTo(11);
    require(one.finished() && one.stars().empty() && one.embers().empty() && one.smoke().empty() &&
                one.rocketTrail().empty(),
            "show must clean up completely");
    auto pcm = fireworks::synthesizeShow(73);
    require(pcm.size() == 11 * 48000 * 4, "audio must match show duration and stereo format");
    require(pcm == fireworks::synthesizeShow(73), "audio must be reproducible");
    bool audible = false, stereo = false;
    for (int frame = 0; frame < 11 * 48000; ++frame) {
        auto left = qFromLittleEndian<qint16>(reinterpret_cast<const uchar *>(pcm.constData()) + frame * 4);
        auto right =
            qFromLittleEndian<qint16>(reinterpret_cast<const uchar *>(pcm.constData()) + frame * 4 + 2);
        if (frame < 2.29 * 48000)
            require(left == 0 && right == 0, "sound must follow the visible explosion");
        audible |= std::abs(int(left)) > 500;
        stereo |= left != right;
        require(std::abs(int(left)) <= 26000 && std::abs(int(right)) <= 26000,
                "audio must retain output headroom");
        if (frame > 10 * 48000)
            require(left == 0 && right == 0, "audio must end cleanly");
    }
    require(audible && stereo, "sound must contain an audible stereo event");
    require(fireworks::waveFile(pcm).startsWith("RIFF"), "export must be a WAV file");
    std::cout << "PASS: deterministic flight, 3D burst, multicolor stars and embers, trails, wind, bounded "
                 "catch-up, cleanup, delayed "
                 "stereo audio\n";
}
