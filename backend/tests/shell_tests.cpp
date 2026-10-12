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
        } else if (type == ShellType::Waterfall || type == ShellType::RainbowRain) {
            require(upward == style.stars, "waterfall must spread into an upward canopy");
            float left = 0, right = 0;
            for (const auto &s : direct.stars()) {
                left = std::min(left, s.velocity.x);
                right = std::max(right, s.velocity.x);
                require(s.velocity.y < 46 && std::abs(s.velocity.z) < 14,
                        "waterfall must form a shallow curtain rather than a sphere");
            }
            require(left < -85 && right > 85, "waterfall curtain must spread widely on both sides");
        } else
            require(upward > style.stars / 3 && upward < style.stars * 2 / 3,
                    "spherical shells must expand both upward and downward");
        if (!style.multicolor)
            require(primary > 0 && secondary > 0 && primary + secondary == style.stars,
                    "authored shells must begin with a coordinated two-color palette");
        else {
            std::array<int, SparkPalette.size()> colors{};
            for (const auto &s : direct.stars()) {
                ++colors[std::size_t(s.color)];
                if (type != ShellType::Prismatic)
                    require(s.transitionStart >= 0.7f && s.finalColor == SparkColor::Amber,
                            "rainbow shells must keep their colors until a late gold finish");
            }
            for (int population : colors)
                require(population >= 8, "multicolor shells must carry all eight authored hues");
        }
        auto speedOf = [](const Star &s) {
            return std::sqrt(s.velocity.x * s.velocity.x + s.velocity.y * s.velocity.y +
                             s.velocity.z * s.velocity.z);
        };
        if (type == ShellType::Dahlia || type == ShellType::Bouquet) {
            const int petals = style.multicolor ? 24 : 16;
            const int beads = style.multicolor ? 12 : 16;
            for (int petal = 0; petal < petals; ++petal) {
                const auto first = direct.stars()[petal * beads].velocity;
                const auto last = direct.stars()[petal * beads + beads - 1].velocity;
                require(speedOf(direct.stars()[petal * beads + beads - 1]) >
                            speedOf(direct.stars()[petal * beads]) * 1.5f,
                        "dahlia petals must have distinct inner and outer beads");
                const float cross = std::abs(first.x * last.y - first.y * last.x);
                require(cross < 250, "dahlia petals must stay in narrow radial bundles");
            }
            for (int i = petals * beads; i < style.stars; ++i)
                require(speedOf(direct.stars()[i]) < 26 &&
                            (style.multicolor || direct.stars()[i].color == style.secondary),
                        "flower shells must have a slow pistil inside their petals");
        }
        if (type == ShellType::Carnival) {
            for (int i = 0; i < style.stars; ++i) {
                const auto v = direct.stars()[i].velocity;
                require(std::abs(-v.y * 0.51f + v.z * 0.86f) < 0.15f,
                        "carnival rings must share a tilted plane");
                const float radius = std::sqrt(v.x * v.x + v.y * v.y / (0.86f * 0.86f));
                require(std::abs(radius - (style.speedMax - (i % 3) * 25)) < 0.8f,
                        "carnival must have three separated hollow rings");
            }
        }
        if (type == ShellType::Star) {
            int tips = 0, notches = 0;
            for (int i = 0; i < style.stars; i += 36) {
                const auto &s = direct.stars()[i];
                require(s.velocity.z == 0, "star outline must face the camera");
                if ((i / 36) % 2 == 0) tips += speedOf(s) > 90;
                else notches += speedOf(s) < 40;
            }
            require(tips == 5 && notches == 5, "star must have five long tips and five deep notches");
            for (const auto &s : direct.stars())
                require(s.velocity.z == 0 && speedOf(s) > 30,
                        "star must remain a hollow planar outline");
        }
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
        if (type == ShellType::Heart) {
            const auto &stars = direct.stars();
            require(std::abs(stars[0].velocity.x) < 0.01f &&
                        stars[0].velocity.y > 20 && stars[0].velocity.y < 30,
                    "heart must have a central notch above the burst");
            require(stars[style.stars / 2].velocity.y < -80,
                    "heart must have a pointed lower tip");
            float lobeHeight = 0;
            for (const auto &s : stars) {
                require(s.velocity.z == 0, "heart must remain camera-facing");
                if (std::abs(s.velocity.x) > 30)
                    lobeHeight = std::max(lobeHeight, s.velocity.y);
            }
            require(lobeHeight > 50, "heart lobes must rise above the notch");
        }
        if (type == ShellType::Saturn) {
            for (std::size_t i = 0; i < direct.stars().size(); ++i) {
                const auto &s = direct.stars()[i];
                if (i % 2 == 0) {
                    require(speedOf(s) > 70 && s.color == style.secondary,
                            "Saturn must have a wide cyan orbit");
                    require(std::abs(-s.velocity.y * RingTiltSin +
                                     s.velocity.z * RingTiltCos) < 1,
                            "Saturn orbit must lie in its tilted plane");
                } else
                    require(speedOf(s) < 33 && s.color == style.primary,
                            "Saturn planet must fit inside the orbit");
            }
        }
        if (type == ShellType::Spiral) {
            for (int i = 0; i < style.stars; ++i) {
                const auto &s = direct.stars()[i];
                require(s.velocity.z == 0, "spiral arms must remain camera-facing");
                if (i >= 3) {
                    const auto &prev = direct.stars()[i - 3];
                    require(speedOf(s) > speedOf(prev), "spiral arms must grow outwards");
                    require(prev.velocity.x * s.velocity.y - prev.velocity.y * s.velocity.x > 0,
                            "spiral arms must curve consistently instead of forming radial spokes");
                }
            }
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
    require(shellIndex("chrysanthemum") == 0 && shellIndex("prismatic") == 3 &&
                shellIndex("crossette") == 6 && shellIndex("heart") == 7,
            "new shells must preserve saved selection indices");
    require(synthesizeShow(73, 48000, ShellType(-1)).isEmpty(), "invalid audio shell must be rejected");
    require(Simulation(73, ShellType(-1)).shellType() == ShellType::Chrysanthemum,
            "invalid native simulation shell must use the safe default");
    Simulation switched(73, ShellType::Willow);
    switched.advanceTo(5);
    switched.setShellType(ShellType::Palm);
    require(switched.time() == 0 && switched.stars().empty(), "switching shell must reset old particles");
}
