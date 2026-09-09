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
    for (float origin : {-fireworks::LaunchSpread, 0.f, fireworks::LaunchSpread}) {
        Simulation flight(73);
        flight.setOrigin(origin);
        flight.setWind(12);
        float previousHeight = flight.rocket().y;
        while (!flight.burst()) {
            flight.advanceTo(flight.time() + Simulation::Step);
            require(flight.rocket().x == origin && flight.rocket().z == 0,
                    "rocket must rise vertically above its launch position through the burst");
            require(flight.rocket().y > previousHeight, "rocket must keep rising until it bursts");
            previousHeight = flight.rocket().y;
        }
        for (const auto &point : flight.rocketTrail())
            require(point.position.x == origin && point.position.z == 0,
                    "the entire rocket trail must follow the vertical launch line");
    }
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

    // --- launch position -------------------------------------------------
    // The burst has to land where the launch was moved to, and not merely
    // somewhere different: a rocket that drifts on its own would satisfy an
    // inequality but not this.
    fireworks::Simulation centred(73), shifted(73);
    shifted.setOrigin(120);
    require(centred.origin() == 0, "a shell must launch from the centre by default");
    require(shifted.origin() == 120, "the launch position must be taken as given");
    centred.advanceTo(fireworks::Simulation::BurstTime + fireworks::Simulation::Step);
    shifted.advanceTo(fireworks::Simulation::BurstTime + fireworks::Simulation::Step);
    require(std::abs((shifted.burstPosition().x - centred.burstPosition().x) - 120) < 0.01f,
            "moving the launch must move the burst by the same distance");
    require(std::abs(shifted.burstPosition().y - centred.burstPosition().y) < 0.01f &&
                std::abs(shifted.burstPosition().z - centred.burstPosition().z) < 0.01f,
            "moving the launch sideways must not change its height or depth");
    require(shifted.stars().size() == centred.stars().size(),
            "the launch position must not change the shell itself");

    fireworks::Simulation clamped(73);
    clamped.setOrigin(4000);
    require(clamped.origin() == fireworks::LaunchSpread, "an off-screen launch must be clamped, not taken");
    clamped.setOrigin(std::numeric_limits<float>::quiet_NaN());
    require(clamped.origin() == fireworks::LaunchSpread, "a non-finite launch position must be refused");

    fireworks::Simulation moved(73);
    moved.advanceTo(5);
    moved.setOrigin(-90);
    require(moved.time() == 0 && moved.stars().empty(),
            "moving the launch must restart the show, not teleport a burst mid-flight");

    // The stereo image leans towards the launch, so the same show at two
    // positions is two different tracks — which is why the audio cache is keyed
    // on the position as well as the seed and the shell.
    const auto left = fireworks::synthesizeShow(73, 48000, fireworks::ShellType::Chrysanthemum, -1.f);
    const auto right = fireworks::synthesizeShow(73, 48000, fireworks::ShellType::Chrysanthemum, 1.f);
    require(left.size() == pcm.size() && right.size() == pcm.size(),
            "a placed show must still be a full-length track");
    require(left != right && left != pcm, "the stereo image must follow the launch position");
    require(left == fireworks::synthesizeShow(73, 48000, fireworks::ShellType::Chrysanthemum, -1.f),
            "a placed show must stay reproducible");
    long long leftEnergy = 0, rightEnergy = 0;
    for (int frame = 0; frame < 11 * 48000; ++frame) {
        const auto *at = reinterpret_cast<const uchar *>(left.constData()) + frame * 4;
        leftEnergy += std::abs(int(qFromLittleEndian<qint16>(at)));
        rightEnergy += std::abs(int(qFromLittleEndian<qint16>(at + 2)));
    }
    require(leftEnergy > rightEnergy, "a shell launched to the left must be louder on the left");
    std::cout << "PASS: deterministic flight, 3D burst, multicolor stars and embers, trails, wind, bounded "
                 "catch-up, cleanup, delayed "
                 "stereo audio\n";
}
