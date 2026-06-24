local particle = require("lib.particle")
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
    local system = particle.new(config.PARTICLE)
    local particles = system:spawn(7)
    eq(#particles, 7, "count")
end)

test("spawn() with no args produces a count within configured min/max", function()
    local system = particle.new(config.PARTICLE)
    for _ = 1, 20 do
        local n = #system:spawn()
        if n < config.PARTICLE.COUNT_MIN or n > config.PARTICLE.COUNT_MAX then
            error("count out of range: " .. n)
        end
    end
end)

test("spawned particles start within normalized [0,1] bounds", function()
    local system = particle.new(config.PARTICLE)
    local particles = system:spawn(50)
    for _, p in ipairs(particles) do
        if p.x < 0 or p.x > 1 or p.y < 0 or p.y > 1 then
            error("position out of bounds: " .. p.x .. ", " .. p.y)
        end
    end
end)

test("spawned particles use a color from the configured palette", function()
    local system = particle.new(config.PARTICLE)
    local particles = system:spawn(50)
    for _, p in ipairs(particles) do
        local found = false
        for _, c in ipairs(config.PARTICLE.COLORS) do
            if c == p.color then found = true; break end
        end
        eq(found, true, "color must be a reference into config.PARTICLE.COLORS")
    end
end)

test("spawned particles have a lifetime within the configured range", function()
    local system = particle.new(config.PARTICLE)
    local particles = system:spawn(50)
    for _, p in ipairs(particles) do
        if p.lifetime < config.PARTICLE.LIFETIME_MIN or p.lifetime > config.PARTICLE.LIFETIME_MAX then
            error("lifetime out of range: " .. p.lifetime)
        end
    end
end)

test("update(dt) applies gravity to vy then integrates position", function()
    local system = particle.new(config.PARTICLE)
    local p = system:spawn(1)[1]
    local x0, y0, vx0, vy0 = p.x, p.y, p.vx, p.vy
    p:update(0.1)
    local expected_vy = vy0 + config.PARTICLE.GRAVITY * 0.1
    eq(p.vy, expected_vy, "vy after gravity")
    eq(p.x, x0 + vx0 * 0.1, "x after update")
    eq(p.y, y0 + expected_vy * 0.1, "y after update")
end)

test("is_dead() is false before lifetime elapses, true once it's reached", function()
    local system = particle.new(config.PARTICLE)
    local p = system:spawn(1)[1]
    p.lifetime = 1.0
    p._timer   = 0
    p:update(0.5)
    eq(p:is_dead(), false, "not dead at half lifetime")
    p:update(0.5)
    eq(p:is_dead(), true, "dead once lifetime is reached")
end)

test("two systems with different cfg tables are independent", function()
    local cfg_a = {
        COUNT_MIN = 3, COUNT_MAX = 3,
        SPEED_MIN = 0, SPEED_MAX = 0,
        LIFETIME_MIN = 1, LIFETIME_MAX = 1,
        GRAVITY = 1.0,
        COLORS = { "red" },
    }
    local cfg_b = {
        COUNT_MIN = 5, COUNT_MAX = 5,
        SPEED_MIN = 0, SPEED_MAX = 0,
        LIFETIME_MIN = 1, LIFETIME_MAX = 1,
        GRAVITY = 9.0,
        COLORS = { "blue" },
    }

    local pa = particle.new(cfg_a):spawn()[1]
    local pb = particle.new(cfg_b):spawn()[1]

    eq(pa.color, "red", "system a uses its own palette")
    eq(pb.color, "blue", "system b uses its own palette")

    pa:update(1.0)
    pb:update(1.0)
    eq(pa.vy, 1.0, "system a's particle uses cfg_a's gravity")
    eq(pb.vy, 9.0, "system b's particle uses cfg_b's gravity")

    eq(#particle.new(cfg_a):spawn(), 3, "system a uses its own count range")
    eq(#particle.new(cfg_b):spawn(), 5, "system b uses its own count range")
end)

test("new() raises a clear error when cfg is missing a required field", function()
    local incomplete = {
        COUNT_MIN = 1, COUNT_MAX = 1,
        SPEED_MIN = 0, SPEED_MAX = 0,
        LIFETIME_MIN = 1, LIFETIME_MAX = 1,
        COLORS = { "red" },
        -- GRAVITY is missing
    }
    local ok, err = pcall(particle.new, incomplete)
    eq(ok, false, "new() should reject an incomplete cfg")
    if not tostring(err):find("GRAVITY") then
        error("expected error to name the missing field 'GRAVITY', got: " .. tostring(err))
    end
end)

test("new() accepts a cfg with extra fields beyond the defaults", function()
    local extra = {
        COUNT_MIN = 1, COUNT_MAX = 1,
        SPEED_MIN = 0, SPEED_MAX = 0,
        LIFETIME_MIN = 1, LIFETIME_MAX = 1,
        GRAVITY = 1.0,
        COLORS = { "red" },
        EXTRA_FIELD = "unused",
    }
    local system = particle.new(extra)
    eq(#system:spawn(1), 1, "count")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
