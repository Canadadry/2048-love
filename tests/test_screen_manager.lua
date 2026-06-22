local screen_manager = require("screen_manager")

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

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("new() calls enter() on the initial screen", function()
    local entered = false
    local initial = { enter = function() entered = true end }
    screen_manager.new(initial)
    eq(entered, true, "initial screen must be entered")
end)

-- ── Cycle 2: promote pauses old top, enters new, keeps old on stack ──────────

test("promote() pauses old top and enters the new screen", function()
    local log = {}
    local game = { pause = function() log[#log + 1] = "game.pause" end }
    local pause_screen = { enter = function() log[#log + 1] = "pause.enter" end }
    local sm = screen_manager.new(game)
    sm:promote(pause_screen)
    eq(log[1], "game.pause",  "old top must be paused first")
    eq(log[2], "pause.enter", "new screen must be entered second")
    eq(#log, 2, "no extra lifecycle calls")
end)

test("promote() does not exit the old top", function()
    local exited = false
    local game = { exit = function() exited = true end }
    local sm = screen_manager.new(game)
    sm:promote({})
    eq(exited, false, "old top must remain on the stack, not exited")
end)

-- ── Cycle 3: dispatch reaches only the top screen ────────────────────────────

test("keypressed reaches only the top screen, not a paused one beneath", function()
    local received = {}
    local game = { keypressed = function(_, k) received[#received + 1] = "game:" .. k end }
    local pause_screen = { keypressed = function(_, k) received[#received + 1] = "pause:" .. k end }
    local sm = screen_manager.new(game)
    sm:promote(pause_screen)
    sm:keypressed("left")
    eq(#received, 1, "exactly one handler called")
    eq(received[1], "pause:left", "only the top screen receives the key")
end)

test("unknown method calls forward to the top screen only", function()
    local game = { score = function() return 10 end }
    local pause_screen = { score = function() return 99 end }
    local sm = screen_manager.new(game)
    eq(sm:score(), 10, "score forwarded from initial top")
    sm:promote(pause_screen)
    eq(sm:score(), 99, "score forwarded from new top after promote, not the paused screen")
end)

-- ── Cycle 4: dismiss exits top, resumes new top ──────────────────────────────

test("dismiss() exits the top screen and resumes the new top", function()
    local log = {}
    local game = { resume = function() log[#log + 1] = "game.resume" end }
    local pause_screen = { exit = function() log[#log + 1] = "pause.exit" end }
    local sm = screen_manager.new(game)
    sm:promote(pause_screen)
    sm:dismiss()
    eq(log[1], "pause.exit",   "old top must be exited first")
    eq(log[2], "game.resume",  "new top must be resumed second")
    eq(#log, 2, "no extra lifecycle calls")
end)

test("dismiss() returns dispatch to the underlying screen", function()
    local game = { score = function() return 10 end }
    local pause_screen = { score = function() return 99 end }
    local sm = screen_manager.new(game)
    sm:promote(pause_screen)
    sm:dismiss()
    eq(sm:score(), 10, "dispatch goes back to the resumed screen")
end)

-- ── Cycle 5: dismiss() on a single-screen stack errors ───────────────────────

test("dismiss() on a single-screen stack raises an error", function()
    local sm = screen_manager.new({})
    local ok = pcall(function() sm:dismiss() end)
    eq(ok, false, "dismiss() with nothing left to dismiss to must error")
end)

-- ── Cycle 6: replace() exits all, leaves single new root ────────────────────

test("replace() exits every screen top-to-bottom and enters the new root", function()
    local log = {}
    local game = { exit = function() log[#log + 1] = "game.exit" end }
    local pause_screen = { exit = function() log[#log + 1] = "pause.exit" end }
    local menu = { enter = function() log[#log + 1] = "menu.enter" end }
    local sm = screen_manager.new(game)
    sm:promote(pause_screen)
    sm:replace(menu)
    eq(log[1], "pause.exit", "topmost screen exits first")
    eq(log[2], "game.exit",  "screens exit top-to-bottom")
    eq(log[3], "menu.enter", "new root entered last")
    eq(#log, 3, "no extra lifecycle calls")
end)

test("replace() leaves a single-entry stack with nothing left to dismiss", function()
    local game = { exit = function() end }
    local menu = {}
    local sm = screen_manager.new(game)
    sm:promote({ exit = function() end })
    sm:replace(menu)
    local ok = pcall(function() sm:dismiss() end)
    eq(ok, false, "replace() must leave only the new root on the stack")
end)

-- ── Cycle 7: missing lifecycle methods are no-ops ────────────────────────────

test("promote() does not crash when screens lack pause()/enter()", function()
    local sm = screen_manager.new({})
    sm:promote({})
    eq(true, true, "no crash")
end)

test("dismiss() does not crash when screens lack exit()/resume()", function()
    local sm = screen_manager.new({})
    sm:promote({})
    sm:dismiss()
    eq(true, true, "no crash")
end)

test("replace() does not crash when screens lack exit()/enter()", function()
    local sm = screen_manager.new({})
    sm:replace({})
    eq(true, true, "no crash")
end)

test("update does not crash when the top screen has no update()", function()
    local sm = screen_manager.new({})
    sm:update(0.016)
    eq(true, true, "no crash")
end)

-- ── Cycle 8: draw() skips to the topmost opaque screen ───────────────────────

test("draw() skips screens below the topmost opaque screen", function()
    local log = {}
    local a = { opaque = function() return true end,  draw = function() log[#log + 1] = "a" end }
    local b = { opaque = function() return true end,  draw = function() log[#log + 1] = "b" end }
    local c = { opaque = function() return false end, draw = function() log[#log + 1] = "c" end }
    local sm = screen_manager.new(a)
    sm:promote(b)
    sm:promote(c)
    sm:draw()
    eq(#log, 2, "only draws from the topmost opaque screen upward")
    eq(log[1], "b", "topmost opaque screen draws first")
    eq(log[2], "c", "overlay draws on top of it")
end)

test("draw() treats a screen without opaque() as opaque", function()
    local log = {}
    local game = { draw = function() log[#log + 1] = "game" end }
    local sm = screen_manager.new(game)
    sm:draw()
    eq(log[1], "game", "screen without opaque() defaults to opaque and draws")
end)

test("draw() does not crash when the top screen has no draw()", function()
    local sm = screen_manager.new({})
    sm:draw()
    eq(true, true, "no crash")
end)

-- ── Cycle 9: re-entrancy guard on promote/replace/dismiss ────────────────────

test("promote() errors if a screen's enter() calls promote() again", function()
    local sm
    local b = { enter = function() sm:promote({}) end }
    sm = screen_manager.new({})
    local ok = pcall(function() sm:promote(b) end)
    eq(ok, false, "nested promote during an in-progress transition must error")
end)

test("replace() errors if a screen's enter() calls replace() again", function()
    local sm
    local menu = { enter = function() sm:replace({}) end }
    sm = screen_manager.new({})
    local ok = pcall(function() sm:replace(menu) end)
    eq(ok, false, "nested replace during an in-progress transition must error")
end)

test("dismiss() errors if a screen's exit() calls dismiss() again", function()
    local sm
    local c = { exit = function() sm:dismiss() end }
    sm = screen_manager.new({})
    sm:promote({})
    sm:promote(c)
    local ok = pcall(function() sm:dismiss() end)
    eq(ok, false, "nested dismiss during an in-progress transition must error")
end)

test("the manager recovers after a guarded transition errors", function()
    local sm
    local b = { enter = function() sm:promote({}) end }
    sm = screen_manager.new({})
    pcall(function() sm:promote(b) end)
    local ok = pcall(function() sm:promote({}) end)
    eq(ok, true, "a later, non-nested transition must still succeed")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
