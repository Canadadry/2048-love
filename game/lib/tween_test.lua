local tween = require("lib.tween")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("Linear/In at current=0 returns from", function()
    local ease = tween.new(tween.Curve.Linear, tween.Mode.In)
    eq(ease(10, 20, 1, 0), 10, "at current=0 must return from")
end)

test("Linear/In at current=duration returns to", function()
    local ease = tween.new(tween.Curve.Linear, tween.Mode.In)
    eq(ease(10, 20, 1, 1), 20, "at current=duration must return to")
end)

-- ── Cycle 7: All curves × all modes — boundary conditions ────────────────────

local curves = {
    tween.Curve.Linear, tween.Curve.Quad,  tween.Curve.Cubic, tween.Curve.Sine,
    tween.Curve.Expo,   tween.Curve.Back,  tween.Curve.Elastic, tween.Curve.Bounce,
}
local modes = { tween.Mode.In, tween.Mode.Out, tween.Mode.InOut, tween.Mode.OutIn }

for _, curve in ipairs(curves) do
    for _, mode in ipairs(modes) do
        local label = curve.name .. "/" .. mode.name
        test(label .. " at current=0 returns from", function()
            local ease = tween.new(curve, mode)
            eq(ease(5, 95, 1, 0), 5, label .. ": at 0 must return from")
        end)
        test(label .. " at current=duration returns to", function()
            local ease = tween.new(curve, mode)
            eq(ease(5, 95, 1, 1), 95, label .. ": at duration must return to")
        end)
    end
end

-- ── Cycle 6: InOut midpoint symmetry ─────────────────────────────────────────

test("Quad/InOut at midpoint returns exact midpoint", function()
    local ease = tween.new(tween.Curve.Quad, tween.Mode.InOut)
    eq(ease(0, 100, 2, 1), 50, "InOut midpoint must be (from+to)/2")
end)

-- ── Cycle 5: Quad/Out shape ───────────────────────────────────────────────────

test("Quad/Out at midpoint is faster than linear (above midpoint)", function()
    local quad_out = tween.new(tween.Curve.Quad, tween.Mode.Out)
    local linear   = tween.new(tween.Curve.Linear, tween.Mode.In)
    local q = quad_out(0, 100, 1, 0.5)
    local l = linear(0, 100, 1, 0.5)
    if q <= l then
        error("Quad/Out midpoint " .. q .. " must exceed linear midpoint " .. l)
    end
end)

-- ── Cycle 4: kind validation ──────────────────────────────────────────────────

test("new() errors on invalid curve", function()
    local ok = pcall(tween.new, {}, tween.Mode.In)
    eq(ok, false, "invalid curve must error")
end)

test("new() errors on invalid mode", function()
    local ok = pcall(tween.new, tween.Curve.Linear, {})
    eq(ok, false, "invalid mode must error")
end)

-- ── Cycle 3: Linear midpoint ──────────────────────────────────────────────────

test("Linear/In at midpoint returns (from+to)/2", function()
    local ease = tween.new(tween.Curve.Linear, tween.Mode.In)
    eq(ease(0, 100, 2, 1), 50, "midpoint must be exact average")
end)

-- ── Cycle 2: Clamping ─────────────────────────────────────────────────────────

test("current < 0 clamps to from", function()
    local ease = tween.new(tween.Curve.Linear, tween.Mode.In)
    eq(ease(10, 20, 1, -1), 10, "negative current must return from")
end)

test("current > duration clamps to to", function()
    local ease = tween.new(tween.Curve.Linear, tween.Mode.In)
    eq(ease(10, 20, 1, 2), 20, "current past duration must return to")
end)

-- ── tween.ease — simplified progress easer ───────────────────────────────────

test("ease() returns a function", function()
    local f = tween.ease(tween.Curve.Linear, tween.Mode.In)
    eq(type(f), "function", "ease() must return a function")
end)

test("ease() at progress 0 returns 0", function()
    local f = tween.ease(tween.Curve.Linear, tween.Mode.In)
    eq(f(0), 0, "progress 0 must map to 0")
end)

test("ease() at progress 1 returns 1", function()
    local f = tween.ease(tween.Curve.Linear, tween.Mode.In)
    eq(f(1), 1, "progress 1 must map to 1")
end)

test("ease(Sine/Out) at midpoint is ahead of linear (eases out = fast start)", function()
    local sine_out = tween.ease(tween.Curve.Sine, tween.Mode.Out)
    local linear   = tween.ease(tween.Curve.Linear, tween.Mode.In)
    local s = sine_out(0.5)
    local l = linear(0.5)
    if s <= l then
        error("Sine/Out at 0.5 should be > linear 0.5, got " .. s .. " vs " .. l)
    end
end)

T.report()
