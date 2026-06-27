local screen_manager = require("lib.screen_manager")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("new() calls enter() on the initial screen", function()
    local entered = false
    local initial = { enter = function() entered = true end }
    screen_manager.new(initial)
    eq(entered, true, "initial screen must be entered")
end)

-- ── Cycle 2: instant replace() exits old, enters new ─────────────────────────

test("replace() exits the old screen and enters the new one", function()
    local log = {}
    local old = { exit = function() log[#log + 1] = "old.exit" end }
    local new_screen = { enter = function() log[#log + 1] = "new.enter" end }
    local sm = screen_manager.new(old)
    sm:replace(new_screen)
    eq(log[1], "old.exit",   "old screen must be exited first")
    eq(log[2], "new.enter",  "new screen must be entered second")
    eq(#log, 2, "no extra lifecycle calls")
end)

test("replace() makes top() return the new screen", function()
    local old = { id = "old" }
    local new_screen = { id = "new" }
    local sm = screen_manager.new(old)
    sm:replace(new_screen)
    eq(sm:top().id, "new", "top() must be the new screen after replace")
end)

-- ── Cycle 3: missing lifecycle methods are no-ops ────────────────────────────

test("replace() does not crash when screens lack exit()/enter()", function()
    local sm = screen_manager.new({})
    sm:replace({})
    eq(true, true, "no crash")
end)

test("update does not crash when the current screen has no update()", function()
    local sm = screen_manager.new({})
    sm:update(0.016)
    eq(true, true, "no crash")
end)

test("draw() does not crash when the current screen has no draw()", function()
    local sm = screen_manager.new({})
    sm:draw()
    eq(true, true, "no crash")
end)

test("keypressed does not crash when the current screen has no keypressed()", function()
    local sm = screen_manager.new({})
    sm:keypressed("left")
    eq(true, true, "no crash")
end)

-- ── Cycle 4: dispatch reaches only current screen ────────────────────────────

test("update(dt) dispatches to _current only (no stack)", function()
    local log = {}
    local screen = { update = function(_, dt) log[#log + 1] = "screen:" .. dt end }
    local sm = screen_manager.new(screen)
    sm:update(0.016)
    eq(#log, 1, "exactly one update call")
    eq(log[1], "screen:0.016", "current screen updated")
end)

test("keypressed dispatches to the current screen", function()
    local received = {}
    local screen = { keypressed = function(_, k) received[#received + 1] = k end }
    local sm = screen_manager.new(screen)
    sm:keypressed("left")
    eq(#received, 1, "exactly one call")
    eq(received[1], "left", "key forwarded to current screen")
end)

test("top() returns the current screen", function()
    local screen = { id = "a" }
    local sm = screen_manager.new(screen)
    eq(sm:top().id, "a", "top() is the initial screen")
end)

-- ── Cycle 5: animated transition — both screens update ───────────────────────

test("during an animated transition, both outgoing and incoming screens receive update(dt)", function()
    love.graphics.newCanvas = function() return {} end
    local log = {}
    local outgoing = { update = function(_, dt) log[#log + 1] = "out:" .. dt end }
    local incoming = { enter = function() end, update = function(_, dt) log[#log + 1] = "in:" .. dt end }
    local sm = screen_manager.new(outgoing)
    sm:replace(incoming, function() end, 0.3)
    sm:update(0.1)
    eq(#log, 2, "both screens must update during transition")
    -- order: implementation-defined, but both must appear
    local has_out = log[1] == "out:0.1" or log[2] == "out:0.1"
    local has_in  = log[1] == "in:0.1"  or log[2] == "in:0.1"
    eq(has_out, true, "outgoing screen updated")
    eq(has_in,  true, "incoming screen updated")
end)

-- ── Cycle 6: transition completes when elapsed >= duration ───────────────────

test("transition ends after enough dt: exit() called on outgoing, current becomes incoming", function()
    love.graphics.newCanvas = function() return {} end
    local log = {}
    local outgoing = { exit = function() log[#log + 1] = "out.exit" end }
    local incoming = { enter = function() end }
    local sm = screen_manager.new(outgoing)
    sm:replace(incoming, function() end, 0.3)
    sm:update(0.4) -- exceeds duration
    eq(#log, 1, "exit() called once on outgoing")
    eq(log[1], "out.exit", "outgoing screen exited at transition end")
    eq(sm:top(), incoming, "top() is now the incoming screen")
end)

test("top() returns the outgoing screen while transition is in progress", function()
    love.graphics.newCanvas = function() return {} end
    local outgoing = { id = "out" }
    local incoming = { enter = function() end, id = "in" }
    local sm = screen_manager.new(outgoing)
    sm:replace(incoming, function() end, 0.5)
    eq(sm:top().id, "out", "top() is still the outgoing screen during transition")
    sm:update(0.6) -- complete transition
    eq(sm:top().id, "in", "top() switches to incoming only after transition ends")
end)

-- ── Cycle 7: input is blocked during transition ───────────────────────────────

test("keypressed is silently swallowed during an animated transition", function()
    love.graphics.newCanvas = function() return {} end
    local received = {}
    local outgoing = { keypressed = function(_, k) received[#received + 1] = k end }
    local incoming = { enter = function() end }
    local sm = screen_manager.new(outgoing)
    sm:replace(incoming, function() end, 0.5)
    sm:keypressed("left")
    eq(#received, 0, "keypressed must be swallowed during transition")
end)

test("resize is silently swallowed during an animated transition", function()
    love.graphics.newCanvas = function() return {} end
    local resize_called = false
    local outgoing = { resize = function() resize_called = true end }
    local incoming = { enter = function() end }
    local sm = screen_manager.new(outgoing)
    sm:replace(incoming, function() end, 0.5)
    sm:resize(800, 600)
    eq(resize_called, false, "resize must be swallowed during transition")
end)

test("keypressed dispatches again after transition completes", function()
    love.graphics.newCanvas = function() return {} end
    local received = {}
    local outgoing = {}
    local incoming = { enter = function() end, keypressed = function(_, k) received[#received + 1] = k end }
    local sm = screen_manager.new(outgoing)
    sm:replace(incoming, function() end, 0.3)
    sm:update(0.5) -- complete transition
    sm:keypressed("right")
    eq(#received, 1, "keypressed dispatches to incoming after transition ends")
    eq(received[1], "right", "correct key forwarded")
end)

-- ── Cycle 8: replace while transition in progress errors ─────────────────────

test("calling replace() while a transition is already in progress raises an error", function()
    love.graphics.newCanvas = function() return {} end
    local outgoing = {}
    local incoming = { enter = function() end }
    local sm = screen_manager.new(outgoing)
    sm:replace(incoming, function() end, 0.5)
    local ok = pcall(function() sm:replace({}, function() end, 0.3) end)
    eq(ok, false, "replace() during an active transition must error")
end)

-- ── Cycle 9: re-entrancy guard on instant replace ────────────────────────────

test("replace() errors if a screen's enter() calls replace() again", function()
    local sm
    local menu = { enter = function() sm:replace({}) end }
    sm = screen_manager.new({})
    local ok = pcall(function() sm:replace(menu) end)
    eq(ok, false, "nested replace during an in-progress transition must error")
end)

test("the manager recovers after a guarded transition errors", function()
    local sm
    local menu = { enter = function() sm:replace({}) end }
    sm = screen_manager.new({})
    pcall(function() sm:replace(menu) end)
    local ok = pcall(function() sm:replace({}) end)
    eq(ok, true, "a later, non-nested replace must still succeed")
end)

-- ── Cycle 10: is_transitioning() ─────────────────────────────────────────────

test("is_transitioning() returns false when idle", function()
    local sm = screen_manager.new({})
    eq(sm:is_transitioning(), false, "not transitioning at rest")
end)

test("is_transitioning() returns true during an animated transition", function()
    love.graphics.newCanvas = function() return {} end
    local sm = screen_manager.new({})
    sm:replace({ enter = function() end }, function() end, 0.5)
    eq(sm:is_transitioning(), true, "transitioning after animated replace")
end)

test("is_transitioning() returns false after the transition completes", function()
    love.graphics.newCanvas = function() return {} end
    local sm = screen_manager.new({})
    sm:replace({ enter = function() end }, function() end, 0.3)
    sm:update(0.4)
    eq(sm:is_transitioning(), false, "not transitioning after it ends")
end)

-- ── quit() ────────────────────────────────────────────────────────────────────

test("quit() calls love.event.quit()", function()
    local quit_calls = 0
    love.event = { quit = function() quit_calls = quit_calls + 1 end }
    local sm = screen_manager.new({})
    sm:quit()
    eq(quit_calls, 1, "quit() must call love.event.quit()")
end)

-- ── spawn() ───────────────────────────────────────────────────────────────────

test("spawn(name) with no previous screen calls the registered screen's new() with nil", function()
    local received_host, received_previous
    local registry = {
        foo = { new = function(host, previous) received_host, received_previous = host, previous end },
    }
    local sm = screen_manager.new({}, registry)
    sm:spawn("foo")
    eq(received_host, sm, "the manager itself is passed as host")
    eq(received_previous, nil, "no previous screen means nil is forwarded")
end)

test("spawn(name, previous) forwards the given previous screen", function()
    local received_previous
    local registry = {
        foo = { new = function(host, previous) received_previous = previous end },
    }
    local sm = screen_manager.new({}, registry)
    local previous_screen = {}
    sm:spawn("foo", previous_screen)
    eq(received_previous, previous_screen, "the previous screen is forwarded as-is")
end)

test("spawn(name, <non-screen>) raises an error", function()
    local registry = { foo = { new = function() end } }
    local sm = screen_manager.new({}, registry)
    local ok = pcall(function() sm:spawn("foo", "not a screen") end)
    eq(ok, false, "a non-nil, non-table second argument must be rejected")
end)

test("spawn() raises an error for an unregistered screen name", function()
    local sm = screen_manager.new({}, {})
    local ok = pcall(function() sm:spawn("unknown") end)
    eq(ok, false, "an unregistered screen name must be rejected")
end)

-- ── Cycle 11: injected ease_fn is applied to progress in draw() ──────────────

local function mock_draw_love()
    love.graphics.newCanvas  = function() return {} end
    love.graphics.setCanvas  = function() end
    love.graphics.clear      = function() end
end

test("draw() applies opts.ease_fn to progress before calling the transition fn", function()
    mock_draw_love()
    local captured_progress
    local fn = function(_, _, progress) captured_progress = progress end
    local double = function(p) return p * 2 end
    local sm = screen_manager.new({}, {}, { ease_fn = double })
    sm:replace({ enter = function() end }, fn, 1.0)
    sm:update(0.25) -- raw progress = 0.25; doubled = 0.5
    sm:draw()
    if math.abs(captured_progress - 0.5) > 0.0001 then
        error("expected eased progress 0.5, got " .. tostring(captured_progress))
    end
end)

test("draw() uses linear progress when no ease_fn is provided", function()
    mock_draw_love()
    local captured_progress
    local fn = function(_, _, progress) captured_progress = progress end
    local sm = screen_manager.new({})
    sm:replace({ enter = function() end }, fn, 1.0)
    sm:update(0.4)
    sm:draw()
    if math.abs(captured_progress - 0.4) > 0.0001 then
        error("expected linear progress 0.4, got " .. tostring(captured_progress))
    end
end)

T.report()
