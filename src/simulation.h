#pragma once
#include "shell.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <vector>

namespace fireworks {
// How far either side of centre a shell may be launched from, in world units.
// Bounded rather than open-ended: a burst is roughly 85 units across, and the
// visible world is about +/-355 units wide on a 16:9 view, so this keeps the
// widest shell inside the frame with room to spare. The simulation does not
// know the viewport — that is the renderer's business — so this is authored
// here rather than derived.
inline constexpr float LaunchSpread = 240.f;
struct Vec3 {
    float x = 0, y = 0, z = 0;
    Vec3 operator+(Vec3 b) const { return {x + b.x, y + b.y, z + b.z}; }
    Vec3 operator-(Vec3 b) const { return {x - b.x, y - b.y, z - b.z}; }
    Vec3 operator*(float s) const { return {x * s, y * s, z * s}; }
    Vec3 &operator+=(Vec3 b) {
        *this = *this + b;
        return *this;
    }
};
struct TrailPoint {
    Vec3 position;
    float time = 0;
    float colorMix = 0;
};
struct Star {
    Vec3 position, velocity;
    float age = 0, lifetime = 0, energy = 0, phase = 0, shed = 0;
    std::array<TrailPoint, 96> trail{};
    int trailHead = 0, trailCount = 0;
    SparkColor color = SparkColor::Amber;
    SparkColor finalColor = SparkColor::Amber;
    float transitionStart = 2, transitionEnd = 3;
    // Set once a crossette star has broken, so it breaks once and its children
    // never break again. Every other shell leaves it false for life.
    bool broken = false;
    float colorMix() const {
        const float x =
            std::clamp((age / lifetime - transitionStart) / (transitionEnd - transitionStart), 0.f, 1.f);
        return x * x * (3 - 2 * x);
    }
};
struct Ember {
    Vec3 position, previous, velocity;
    float age = 0, lifetime = 1, energy = 1, phase = 0;
    SparkColor color = SparkColor::Amber;
    SparkColor finalColor = SparkColor::Amber;
    float colorMix = 0;
};
struct Smoke {
    Vec3 position, velocity;
    float age = 0, lifetime = 5, radius = 1, seed = 0;
    SparkColor color = SparkColor::Amber;
};

class Simulation {
  public:
    static constexpr double Step = 1.0 / 120.0;
    static constexpr double BurstTime = 1.95;
    static constexpr double Duration = 11.0;
    static constexpr std::size_t MaxEmbers = 12000;
    static constexpr std::size_t MaxSmoke = 240;
    explicit Simulation(std::uint32_t seed = 73, ShellType type = ShellType::Chrysanthemum);
    void reset(std::uint32_t seed);
    void setShellType(ShellType type);
    // Where the rocket leaves the ground, along the horizontal axis. Resets the
    // show, as changing the shell does: the flight is already under way and
    // there is no meaningful way to move it mid-climb.
    void setOrigin(float x);
    float origin() const { return m_originX; }
    ShellType shellType() const { return m_shellType; }
    void advanceTo(double seconds, int maxSteps = 1800);
    void setWind(float wind) { m_wind = wind; }
    double time() const { return m_steps * Step; }
    bool burst() const { return m_burst; }
    bool finished() const { return time() >= Duration; }
    const std::vector<Star> &stars() const { return m_stars; }
    const std::vector<Ember> &embers() const { return m_embers; }
    const std::vector<Smoke> &smoke() const { return m_smoke; }
    const std::vector<TrailPoint> &rocketTrail() const { return m_rocketTrail; }
    Vec3 rocket() const { return m_rocket; }
    Vec3 burstPosition() const { return m_burstPosition; }
    std::uint32_t seed() const { return m_seed; }

  private:
    void step();
    void explode();
    void breakCrossettes();
    float random(float low, float high);
    void ember(Vec3 position, Vec3 velocity, float energy, float life, SparkColor color = SparkColor::Amber,
               SparkColor finalColor = SparkColor::Amber, float colorMix = 0);
    ShellType m_shellType;
    std::uint32_t m_seed = 73, m_random = 73;
    int m_steps = 0;
    bool m_burst = false;
    float m_wind = 2.2f;
    float m_originX = 0;
    Vec3 m_rocket, m_velocity, m_burstPosition;
    std::vector<Star> m_stars;
    std::vector<Ember> m_embers;
    std::vector<Smoke> m_smoke;
    std::vector<TrailPoint> m_rocketTrail;
};
} // namespace fireworks
