local check  = require("lib.check")
local config = require("config")

local M = {}
local Particle = {}
Particle.__index = Particle

local function random_velocity()
    local angle = math.random() * 2 * math.pi
    local speed = config.PARTICLE_SPEED_MIN +
        math.random() * (config.PARTICLE_SPEED_MAX - config.PARTICLE_SPEED_MIN)
    return math.cos(angle) * speed, math.sin(angle) * speed
end

local function new_particle()
    local vx, vy = random_velocity()
    return setmetatable({
        x        = math.random(),
        y        = math.random(),
        vx       = vx,
        vy       = vy,
        color    = config.PARTICLE_COLORS[math.random(#config.PARTICLE_COLORS)],
        lifetime = config.PARTICLE_LIFETIME_MIN +
            math.random() * (config.PARTICLE_LIFETIME_MAX - config.PARTICLE_LIFETIME_MIN),
        _timer   = 0,
    }, Particle)
end

function Particle:update(dt)
    check.num(dt, "dt")
    self.vy     = self.vy + config.PARTICLE_GRAVITY * dt
    self.x      = self.x + self.vx * dt
    self.y      = self.y + self.vy * dt
    self._timer = self._timer + dt
end

function Particle:is_dead()
    return self._timer >= self.lifetime
end

function M.spawn(count)
    count = count or math.random(config.PARTICLE_COUNT_MIN, config.PARTICLE_COUNT_MAX)
    check.num(count, "count")
    local particles = {}
    for i = 1, count do
        particles[i] = new_particle()
    end
    return particles
end

return M
