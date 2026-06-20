-- gamestate.lua requires "grid" which in turn is a plain Lua module, but
-- gamestate also requires no Love2D calls at construction time.
local gamestate = require("gamestate")

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

-- Tracer bullet: after a key press that moves tiles, gamestate is animating
test("is_animating() returns true after a move that slides tiles", function()
    local s = gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    eq(s:is_animating(), true, "should be animating after a move")
end)

-- Input is blocked while animations are in flight
test("keypressed is ignored while animations are active", function()
    local s = gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    local score_after_first = s:score()
    -- second key press should be blocked
    s:keypressed("right")
    eq(s:score(), score_after_first, "score unchanged when input blocked")
end)

-- After update() completes animation, is_animating returns false
test("is_animating() returns false after animation duration elapses", function()
    local s = gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    s:update(1.0)  -- way past any animation duration
    eq(s:is_animating(), false, "animation should be done")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
