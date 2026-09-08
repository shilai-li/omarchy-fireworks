#include "audio.h"
#include "simulation.h"
#include <cmath>
#include <cstdlib>
#include <iostream>

void require(bool value, const char *message) {
    if (!value) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}
int main() {
    using namespace fireworks;
    QByteArray previousAudio;
    for (std::size_t kind = 0; kind < Shells.size(); ++kind) {
        const auto type = ShellType(kind);
        const auto &style = Shells[kind];
        require(shellIndex(style.slug) == int(kind), "shell slugs must resolve consistently");
        Simulation direct(73, type), paced(73, type);
        direct.advanceTo(Simulation::BurstTime + Simulation::Step);
        require(direct.stars().size() == std::size_t(style.stars),
                "each shell must have its authored population");
        int upward = 0, primary = 0, secondary = 0;
        for (const auto &s : direct.stars()) {
            upward += s.velocity.y > 0;
            primary += s.color == style.primary;
            secondary += s.color == style.secondary;
        }
        if (type == ShellType::Palm) {
            require(upward == style.stars, "palm must form an upward canopy, not a spherical burst");
            for (int frond = 0; frond < 12; ++frond) {
                float low = 4, high = -4;
                for (int leaf = 0; leaf < 8; ++leaf) {
                    const auto v = direct.stars()[frond * 8 + leaf].velocity;
                    const float angle = std::atan2(v.y, v.x);
                    low = std::min(low, angle);
                    high = std::max(high, angle);
                }
                require(high - low < 0.12f, "palm stars must stay grouped into narrow fronds");
            }
        } else
            require(upward > style.stars / 3 && upward < style.stars * 2 / 3,
                    "spherical shells must expand both upward and downward");
        if (type != ShellType::Prismatic)
            require(primary > 0 && secondary > 0 && primary + secondary == style.stars,
                    "authored shells must begin with a coordinated two-color palette");
        auto speedOf = [](const Star &s) {
            return std::sqrt(s.velocity.x * s.velocity.x + s.velocity.y * s.velocity.y +
                             s.velocity.z * s.velocity.z);
        };
        if (type == ShellType::Ring) {
            // A ring is planar and hollow, and both halves have to be asserted:
            // a sphere would satisfy either one alone. Every velocity lies in
            // the tilted plane, so its component along that plane's normal
            // stays near zero, while no star sits near the centre.
            constexpr float ny = -RingTiltSin, nz = RingTiltCos;
            float worstOut = 0, slowest = 1e9f;
            for (const auto &s : direct.stars()) {
                worstOut = std::max(worstOut, std::abs(s.velocity.y * ny + s.velocity.z * nz));
                slowest = std::min(slowest, speedOf(s));
            }
            require(worstOut < 3.f, "ring stars must lie in a single plane");
            require(slowest > 60.f, "the ring must be hollow — no star may sit near its centre");
        }
        if (type == ShellType::Peony) {
            // Three nested layers, each slower and longer-lived than the one
            // outside it. Means rather than extremes: the shared one-in-13 slow
            // star overlaps the layers at the edges without blurring the bands.
            double speed[3]{}, life[3]{};
            int members[3]{};
            for (std::size_t i = 0; i < direct.stars().size(); ++i) {
                const auto &s = direct.stars()[i];
                speed[i % 3] += speedOf(s);
                life[i % 3] += s.lifetime;
                ++members[i % 3];
            }
            for (int layer = 0; layer < 3; ++layer) {
                require(members[layer] > 0, "every peony layer must be populated");
                speed[layer] /= members[layer];
                life[layer] /= members[layer];
            }
            require(speed[0] > speed[1] * 1.25 && speed[1] > speed[2] * 1.35,
                    "peony layers must be distinctly nested, not one blurred sphere");
            require(life[2] > life[1] && life[1] > life[0],
                    "inner peony layers must outlive the ones outside them");
        }
        if (style.splitInto > 0) {
            Simulation cross(73, type);
            cross.advanceTo(Simulation::BurstTime + Simulation::Step);
            const std::size_t launched = cross.stars().size();
            cross.advanceTo(Simulation::BurstTime + style.lifeMax * style.splitAt + 0.4);
            require(cross.stars().size() > launched * 2, "crossette stars must break into children");
            // 72 parents that each break once into four give 288 stars and no
            // more; children that broke again would run away past this.
            const std::size_t ceiling = launched * std::size_t(style.splitInto);
            for (int tick = 0; tick <= 1320; ++tick) {
                cross.advanceTo(tick * Simulation::Step);
                require(cross.stars().size() <= ceiling, "each crossette star must break once, not repeatedly");
                for (const auto &s : cross.stars())
                    require(s.color == style.primary || s.color == style.secondary,
                            "crossette children must inherit the shell's palette");
            }
        }
        direct.advanceTo(style.fallTime);
        const int ticks = int(std::floor(style.fallTime / Simulation::Step + 1e-7));
        for (int tick = 1; tick <= ticks; ++tick)
            paced.advanceTo(tick * Simulation::Step);
        require(direct.stars().size() == paced.stars().size() &&
                    direct.embers().size() == paced.embers().size(),
                "frame pacing must not change shell populations");
        int changing = 0, historical = 0;
        for (std::size_t i = 0; i < direct.stars().size(); ++i) {
            const auto &a = direct.stars()[i], &b = paced.stars()[i];
            require(a.position.x == b.position.x && a.position.y == b.position.y &&
                        a.position.z == b.position.z && a.colorMix() == b.colorMix(),
                    "shell motion and burn progression must be deterministic");
            require(std::isfinite(a.position.x) && std::isfinite(a.position.y) && std::isfinite(a.position.z),
                    "positions must remain finite");
            changing += a.colorMix() > 0.05f && a.colorMix() < 0.99f;
            for (int j = 0; j < a.trailCount; ++j)
                historical += a.trail[j].colorMix + 0.05f < a.colorMix();
        }
        if (type != ShellType::Prismatic) {
            require(changing > 0 && historical > 0,
                    "changing tips must leave their earlier trail colors intact");
            require(std::any_of(direct.embers().begin(), direct.embers().end(),
                                [](const Ember &e) { return e.color == SparkColor::Amber; }),
                    "authored shells must shed golden crackle near the finish");
        }
        direct.advanceTo(0);
        direct.advanceTo(style.fallTime);
        require(direct.shellType() == type && direct.stars().size() == paced.stars().size(),
                "rewind must preserve the selected shell");
        for (int tick = ticks; tick <= 1320; ++tick) {
            direct.advanceTo(tick * Simulation::Step);
            require(direct.embers().size() <= Simulation::MaxEmbers &&
                        direct.smoke().size() <= Simulation::MaxSmoke,
                    "shell populations must remain bounded through decay");
        }
        require(direct.finished() && direct.stars().empty() && direct.embers().empty() &&
                    direct.smoke().empty(),
                "every shell must finish and release particles");
        auto pcm = synthesizeShow(73, 48000, type);
        require(pcm.size() == 11 * 48000 * 4 && pcm == synthesizeShow(73, 48000, type),
                "shell-specific crackle tracks must have fixed length and seed");
        if (!previousAudio.isEmpty())
            require(pcm != previousAudio, "different shells must have different crackle schedules");
        previousAudio = pcm;
        std::cout << "PASS: " << style.slug << " silhouette, burn history, timing, cleanup, audio\n";
    }
    require(shellIndex("unknown") == -1, "unknown shell must not silently select a preset");
    require(synthesizeShow(73, 48000, ShellType(-1)).isEmpty(), "invalid audio shell must be rejected");
    require(Simulation(73, ShellType(-1)).shellType() == ShellType::Chrysanthemum,
            "invalid native simulation shell must use the safe default");
    Simulation switched(73, ShellType::Willow);
    switched.advanceTo(5);
    switched.setShellType(ShellType::Palm);
    require(switched.time() == 0 && switched.stars().empty(), "switching shell must reset old particles");
}
