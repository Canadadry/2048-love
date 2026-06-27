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

test("push fn resets color to white before drawing canvases to prevent tinting", function()
    local calls = {}
    love.graphics.setColor    = function(r, g, b, a)
        calls[#calls + 1] = { kind = "setColor", r = r, g = g, b = b, a = a }
    end
    love.graphics.setBlendMode = function() end
    love.graphics.draw = function()
        calls[#calls + 1] = { kind = "draw" }
    end

    local fn = transitions.push("left")
    fn({}, {}, 0.5)

    local white_at, first_draw_at
    for i, c in ipairs(calls) do
        if c.kind == "setColor" and c.r == 1 and c.g == 1 and c.b == 1 and c.a == 1 then
            if not white_at then white_at = i end
        elseif c.kind == "draw" then
            if not first_draw_at then first_draw_at = i end
        end
    end
    if not white_at      then error("setColor(1,1,1,1) was never called") end
    if not first_draw_at then error("draw was never called") end
    if white_at >= first_draw_at then
        error("setColor(1,1,1,1) must be called before the first draw")
    end
end)

test("push fn uses premultiplied blend mode when drawing canvases and restores it after", function()
    local calls = {}
    love.graphics.setColor    = function() end
    love.graphics.setBlendMode = function(mode, alphamode)
        calls[#calls + 1] = { kind = "setBlendMode", mode = mode, alphamode = alphamode }
    end
    love.graphics.draw = function()
        calls[#calls + 1] = { kind = "draw" }
    end

    local fn = transitions.push("left")
    fn({}, {}, 0.5)

    local pm_at, first_draw_at, restore_at
    for i, c in ipairs(calls) do
        if c.kind == "setBlendMode" and c.mode == "alpha" and c.alphamode == "premultiplied" then
            if not pm_at then pm_at = i end
        elseif c.kind == "draw" then
            if not first_draw_at then first_draw_at = i end
        elseif c.kind == "setBlendMode" and c.mode == "alpha" and c.alphamode ~= "premultiplied" then
            restore_at = i
        end
    end
    if not pm_at           then error("setBlendMode('alpha','premultiplied') was never called") end
    if not first_draw_at   then error("draw was never called") end
    if pm_at >= first_draw_at then
        error("setBlendMode premultiplied must be called before the first draw")
    end
    if not restore_at or restore_at <= first_draw_at then
        error("blend mode must be restored to alpha after the draws")
    end
end)

T.report()
