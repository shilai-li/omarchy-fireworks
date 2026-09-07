#include "simulation.h"
#include <algorithm>
#include <cmath>

namespace fireworks {
Simulation::Simulation(std::uint32_t seed, ShellType type)
    : m_shellType(int(type) >= 0 && std::size_t(type) < Shells.size() ? type : ShellType::Chrysanthemum) {
    reset(seed);
}
void Simulation::setShellType(ShellType type) {
    if (int(type) < 0 || std::size_t(type) >= Shells.size() || type == m_shellType)
        return;
    m_shellType = type;
    reset(m_seed);
}
void Simulation::reset(std::uint32_t seed) {
    m_seed = seed;
    m_random = seed ? seed : 1;
    m_steps = 0;
    m_burst = false;
    m_rocket = {-26, -55, 0};
    m_velocity = {8, 131, 3};
    m_burstPosition = {};
    m_stars.clear();
    m_embers.clear();
    m_smoke.clear();
    m_rocketTrail.clear();
    m_stars.reserve(520);
    m_embers.reserve(MaxEmbers);
    m_smoke.reserve(MaxSmoke);
    m_rocketTrail.reserve(250);
}
float Simulation::random(float low, float high) {
    // Explicit PRNG keeps captures reproducible across standard libraries.
    m_random ^= m_random << 13;
    m_random ^= m_random >> 17;
    m_random ^= m_random << 5;
    return low + (high - low) * float(m_random >> 8) / 16777216.f;
}
void Simulation::ember(Vec3 p, Vec3 v, float energy, float life, SparkColor color, SparkColor finalColor,
                       float colorMix) {
    if (m_embers.size() >= MaxEmbers)
        return;
    m_embers.push_back({p, p, v, 0, life, energy, random(0, 6.283185f), color, finalColor, colorMix});
}
void Simulation::explode() {
    m_burst = true;
    m_burstPosition = m_rocket;
    const auto &shell = shellDefinition(m_shellType);
    const int count = shell.stars;
    const bool prismatic = m_shellType == ShellType::Prismatic;
    for (int i = 0; i < count; ++i) {
        // Fibonacci shell with restrained jitter: an organic sphere, with depth.
        const float y = 1.f - 2.f * (i + 0.5f) / count;
        const float r = std::sqrt(std::max(0.f, 1 - y * y));
        const float theta = i * 2.39996323f + random(-0.065f, 0.065f);
        const float speed = random(shell.speedMin, shell.speedMax) * (i % 13 == 0 ? 0.65f : 1.f);
        Star star;
        star.position = m_rocket;
        star.velocity = {r * std::cos(theta) * speed, y * speed, r * std::sin(theta) * speed};
        star.lifetime = random(shell.lifeMin, shell.lifeMax);
        star.energy = random(0.75f, 1.65f);
        star.phase = random(0, 6.283185f);
        star.color = prismatic    ? prismaticColor(std::size_t(i), m_seed)
                     : i % 3 == 0 ? shell.secondary
                                  : shell.primary;
        star.finalColor = prismatic ? star.color : SparkColor::Amber;
        star.transitionStart = shell.transitionStart;
        star.transitionEnd = shell.transitionEnd;
        if (m_shellType == ShellType::Chrysanthemum) {
            // A cool inner pistil nested inside a warm spherical envelope.
            const bool inner = i % 7 == 0;
            star.color = inner ? shell.secondary : shell.primary;
            if (inner) {
                star.velocity = star.velocity * 0.48f;
                star.transitionStart = 0.72f;
                star.transitionEnd = 0.95f;
            }
        } else if (m_shellType == ShellType::Palm) {
            // Twelve narrow 3D bundles, not a sparse spherical explosion.
            const int frond = i / 8;
            const float angle = 0.14f + float(frond) / 11 * 2.86159f;
            const float reach = (shell.speedMin + shell.speedMax) * 0.5f * (0.88f + (i % 8) * 0.025f);
            star.velocity = {std::cos(angle) * reach + random(-1.5f, 1.5f),
                             std::sin(angle) * reach * 0.72f + 8 + random(-1.5f, 1.5f),
                             std::sin(frond * 2.39996f) * reach * 0.40f + random(-1, 1)};
            star.color = frond % 3 == 0 ? shell.secondary : shell.primary;
            star.energy *= i % 8 == 7 ? 1.9f : 0.8f;
        }
        star.trail[0] = {star.position, float(time())};
        star.trailCount = 1;
        m_stars.push_back(star);
    }
    for (int i = 0; i < 36; ++i) {
        Vec3 dir{random(-1, 1), random(-0.6f, 1), random(-1, 1)};
        m_smoke.push_back({m_rocket + dir * random(0, 8), dir * random(3, 13), 0, random(4, 7), random(3, 8),
                           random(0, 100),
                           prismatic    ? prismaticColor(std::size_t(i), m_seed)
                           : i % 3 == 0 ? shell.secondary
                                        : shell.primary});
    }
    for (int i = 0; i < 180; ++i)
        ember(m_rocket, {random(-38, 38), random(-30, 45), random(-30, 30)}, random(1, 3),
              random(0.18f, 0.85f), prismatic ? prismaticColor(std::size_t(i), m_seed) : shell.primary);
}
void Simulation::advanceTo(double seconds, int maxSteps) {
    if (!std::isfinite(seconds))
        return;
    seconds = std::clamp(seconds, 0.0, Duration);
    const int target = int(std::floor(seconds / Step + 1e-7));
    if (target < m_steps)
        reset(m_seed);
    for (int n = 0; m_steps < target && n < maxSteps; ++n)
        step();
}
void Simulation::step() {
    constexpr float dt = float(Step);
    ++m_steps;
    const float t = float(time());
    const auto &shell = shellDefinition(m_shellType);
    if (!m_burst) {
        m_velocity.y -= 9.81f * dt;
        m_velocity = m_velocity * std::exp(-0.13f * dt);
        m_rocket += m_velocity * dt;
        m_rocket.x += std::sin(t * 8.f) * 0.45f * dt;
        m_rocketTrail.push_back({m_rocket, t});
        if (m_steps % 2 == 0) {
            for (int j = 0; j < 3; ++j)
                ember(m_rocket, {random(-5, 5), random(-25, -5), random(-5, 5)}, random(0.6f, 1.6f),
                      random(0.3f, 0.9f));
        }
        if (m_steps % 9 == 0 && m_smoke.size() < MaxSmoke)
            m_smoke.push_back({m_rocket,
                               {m_wind * 0.3f, random(-2, 1), 0},
                               0,
                               random(3, 5),
                               random(1.1f, 2.8f),
                               random(0, 100)});
        if (time() + 1e-7 >= BurstTime)
            explode();
    }
    for (auto &s : m_stars) {
        s.age += dt;
        s.velocity = s.velocity * std::exp(-shell.drag * dt);
        s.velocity.y -= 9.81f * dt;
        s.position += (s.velocity + Vec3{m_wind + 0.7f * std::sin(t * 1.4f + s.phase), 0, 0}) * dt;
        if (m_steps % 3 == 0) {
            s.trailHead = (s.trailHead + 1) % int(s.trail.size());
            s.trail[s.trailHead] = {s.position, t, s.colorMix()};
            s.trailCount = std::min(s.trailCount + 1, int(s.trail.size()));
        }
        s.shed += dt;
        if (s.shed >= shell.sheddingInterval && s.age < s.lifetime - 0.4f) {
            s.shed = 0;
            for (int j = 0; j < shell.sheddingCount; ++j)
                ember(s.position,
                      s.velocity * 0.28f + Vec3{random(-2.5f, 2.5f), random(-2, 2), random(-2.5f, 2.5f)},
                      s.energy * random(0.23f, 0.7f), random(0.25f, 0.85f), s.color, s.finalColor,
                      s.colorMix());
        }
        const bool prismatic = m_shellType == ShellType::Prismatic;
        if (s.age > (prismatic ? 2.4f : shell.crackleStart) && s.age < shell.crackleEnd &&
            m_steps % 36 == 0 && random(0, 1) > (m_shellType == ShellType::Palm ? 0.65f : 0.88f))
            for (int j = 0; j < 5; ++j)
                ember(s.position, {random(-8, 8), random(-6, 7), random(-8, 8)},
                      random(0.8f, 2) * (prismatic ? 1.f : 1.6f),
                      prismatic ? random(0.08f, 0.3f) : random(0.12f, 0.45f),
                      prismatic ? s.color : SparkColor::Amber);
        if (s.age < 2.f && m_steps % 36 == 0 && m_smoke.size() < MaxSmoke && random(0, 1) > 0.85f)
            m_smoke.push_back({s.position,
                               {m_wind, 0.6f, 0},
                               0,
                               random(2, 4),
                               random(1.4f, 3.2f),
                               random(0, 100),
                               s.color});
    }
    std::erase_if(m_stars, [](const Star &s) { return s.age >= s.lifetime; });
    for (auto &e : m_embers) {
        e.age += dt;
        e.previous = e.position;
        e.velocity = e.velocity * std::exp(-0.8f * dt);
        e.velocity.y -= 7.f * dt;
        e.position += (e.velocity + Vec3{m_wind, 0, 0}) * dt;
    }
    std::erase_if(m_embers, [](const Ember &e) { return e.age >= e.lifetime; });
    for (auto &s : m_smoke) {
        s.age += dt;
        s.velocity = s.velocity * std::exp(-0.65f * dt);
        s.position += (s.velocity + Vec3{m_wind * 0.75f, 1.2f, 0.3f}) * dt;
    }
    std::erase_if(m_smoke, [](const Smoke &s) { return s.age >= s.lifetime; });
    if (finished()) {
        m_stars.clear();
        m_embers.clear();
        m_smoke.clear();
        m_rocketTrail.clear();
    }
}
} // namespace fireworks
