local transitions = require("lib.transitions")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local function approx(a, b, msg)
    if math.abs(a - b) > 0.0001 then
        error((msg or "approx") .. ": expected " .. b .. ", got " .. a, 2)
    end
end

-- ── push_offsets — progress 0 ─────────────────────────────────────────────────

test("push_offsets left at progress 0: out fills screen, in is fully off to the right", function()
    local ox, oy, ix, iy = transitions.push_offsets("left", 0, 800, 600)
    approx(ox, 0,   "out_x at 0"); approx(oy, 0, "out_y at 0")
    approx(ix, 800, "in_x at 0");  approx(iy, 0, "in_y at 0")
end)

test("push_offsets right at progress 0: out fills screen, in is fully off to the left", function()
    local ox, oy, ix, iy = transitions.push_offsets("right", 0, 800, 600)
    approx(ox, 0,    "out_x at 0"); approx(oy, 0, "out_y at 0")
    approx(ix, -800, "in_x at 0"); approx(iy, 0, "in_y at 0")
end)

-- ── push_offsets — progress 1 ─────────────────────────────────────────────────

test("push_offsets left at progress 1: in fills screen, out is fully off to the left", function()
    local ox, oy, ix, iy = transitions.push_offsets("left", 1, 800, 600)
    approx(ox, -800, "out_x at 1"); approx(oy, 0, "out_y at 1")
    approx(ix, 0,    "in_x at 1"); approx(iy, 0, "in_y at 1")
end)

test("push_offsets right at progress 1: in fills screen, out is fully off to the right", function()
    local ox, oy, ix, iy = transitions.push_offsets("right", 1, 800, 600)
    approx(ox, 800, "out_x at 1"); approx(oy, 0, "out_y at 1")
    approx(ix, 0,   "in_x at 1"); approx(iy, 0, "in_y at 1")
end)

-- ── push_offsets — midpoint ───────────────────────────────────────────────────

test("push_offsets left at progress 0.5: both canvases are exactly half off-screen", function()
    local ox, oy, ix, iy = transitions.push_offsets("left", 0.5, 800, 600)
    approx(ox, -400, "out_x at 0.5"); approx(oy, 0, "out_y at 0.5")
    approx(ix,  400, "in_x at 0.5");  approx(iy, 0, "in_y at 0.5")
end)

-- ── push_offsets — up / down ──────────────────────────────────────────────────

test("push_offsets up at progress 0: out fills screen, in is fully below", function()
    local ox, oy, ix, iy = transitions.push_offsets("up", 0, 800, 600)
    approx(ox, 0, "out_x"); approx(oy, 0,   "out_y at 0")
    approx(ix, 0, "in_x");  approx(iy, 600, "in_y at 0")
end)

test("push_offsets down at progress 1: in fills screen, out is fully below", function()
    local ox, oy, ix, iy = transitions.push_offsets("down", 1, 800, 600)
    approx(ox, 0,   "out_x"); approx(oy, 600,  "out_y at 1")
    approx(ix, 0,   "in_x");  approx(iy, 0,    "in_y at 1")
end)

-- ── push() factory ────────────────────────────────────────────────────────────

test("push(dir) returns a callable function", function()
    local fn = transitions.push("left")
    eq(type(fn), "function", "push() must return a function")
end)

T.report()
