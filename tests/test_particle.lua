local particle = require("particle")
local config   = require("config")

local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("PASS " .. name)
        pass = pass + 1
    else
        print("FAIL " .. name)
        print("     " .. tostring(err))
        fail = fail + 1
    end
end

local function eq(a, b, msg)
    if a ~= b then
        error((msg or "eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

test("spawn(n) returns exactly n particles", function()
    local particles = particle.spawn(7)
    eq(#particles, 7, "count")
end)

test("spawn() with no args produces a count within configured min/max", function()
    for _ = 1, 20 do
        local n = #particle.spawn()
        if n < config.PARTICLE_COUNT_MIN or n > config.PARTICLE_COUNT_MAX then
            error("count out of range: " .. n)
        end
    end
end)

test("spawned particles start within normalized [0,1] bounds", function()
    local particles = particle.spawn(50)
    for _, p in ipairs(particles) do
        if p.x < 0 or p.x > 1 or p.y < 0 or p.y > 1 then
            error("position out of bounds: " .. p.x .. ", " .. p.y)
        end
    end
end)

test("spawned particles use a color from the configured palette", function()
    local particles = particle.spawn(50)
    for _, p in ipairs(particles) do
        local found = false
        for _, c in ipairs(config.PARTICLE_COLORS) do
            if c == p.color then found = true; break end
        end
        eq(found, true, "color must be a reference into config.PARTICLE_COLORS")
    end
end)

test("spawned particles have a lifetime within the configured range", function()
    local particles = particle.spawn(50)
    for _, p in ipairs(particles) do
        if p.lifetime < config.PARTICLE_LIFETIME_MIN or p.lifetime > config.PARTICLE_LIFETIME_MAX then
            error("lifetime out of range: " .. p.lifetime)
        end
    end
end)

test("update(dt) applies gravity to vy then integrates position", function()
    local p = particle.spawn(1)[1]
    local x0, y0, vx0, vy0 = p.x, p.y, p.vx, p.vy
    p:update(0.1)
    local expected_vy = vy0 + config.PARTICLE_GRAVITY * 0.1
    eq(p.vy, expected_vy, "vy after gravity")
    eq(p.x, x0 + vx0 * 0.1, "x after update")
    eq(p.y, y0 + expected_vy * 0.1, "y after update")
end)

test("is_dead() is false before lifetime elapses, true once it's reached", function()
    local p = particle.spawn(1)[1]
    p.lifetime = 1.0
    p._timer   = 0
    p:update(0.5)
    eq(p:is_dead(), false, "not dead at half lifetime")
    p:update(0.5)
    eq(p:is_dead(), true, "dead once lifetime is reached")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
