local check = require("lib.check")

local DEFAULT_CFG = {
    COUNT_MIN = 0, COUNT_MAX = 0,
    LIFETIME_MIN = 0, LIFETIME_MAX = 0,
    SPEED_MIN = 0, SPEED_MAX = 0,
    GRAVITY = 0, COLORS = {},
}

local M = {}
local System = {}
System.__index = System

local Particle = {}
Particle.__index = Particle

local function random_velocity(cfg)
    local angle = math.random() * 2 * math.pi
    local speed = cfg.SPEED_MIN +
        math.random() * (cfg.SPEED_MAX - cfg.SPEED_MIN)
    return math.cos(angle) * speed, math.sin(angle) * speed
end

local function new_particle(cfg)
    local vx, vy = random_velocity(cfg)
    return setmetatable({
        x        = math.random(),
        y        = math.random(),
        vx       = vx,
        vy       = vy,
        color    = cfg.COLORS[math.random(#cfg.COLORS)],
        lifetime = cfg.LIFETIME_MIN +
            math.random() * (cfg.LIFETIME_MAX - cfg.LIFETIME_MIN),
        gravity  = cfg.GRAVITY,
        _timer   = 0,
    }, Particle)
end

function Particle:update(dt)
    check.num(dt, "dt")
    self.vy     = self.vy + self.gravity * dt
    self.x      = self.x + self.vx * dt
    self.y      = self.y + self.vy * dt
    self._timer = self._timer + dt
end

function Particle:is_dead()
    return self._timer >= self.lifetime
end

function M.new(cfg)
    check.fields(cfg, DEFAULT_CFG, "cfg")
    return setmetatable({ cfg = cfg }, System)
end

function System:spawn(count)
    count = count or math.random(self.cfg.COUNT_MIN, self.cfg.COUNT_MAX)
    check.num(count, "count")
    local particles = {}
    for i = 1, count do
        particles[i] = new_particle(self.cfg)
    end
    return particles
end

return M
