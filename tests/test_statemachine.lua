local statemachine = require("statemachine")

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

test("switch calls exit() on old state before enter() on new state", function()
    local log = {}
    local state_a = {
        exit  = function() log[#log + 1] = "a.exit" end,
    }
    local state_b = {
        enter = function() log[#log + 1] = "b.enter" end,
    }
    local sm = statemachine.new(state_a)
    sm:switch(state_b)
    eq(log[1], "a.exit",  "exit() must be called on old state first")
    eq(log[2], "b.enter", "enter() must be called on new state second")
    eq(#log,   2,          "no extra lifecycle calls")
end)

-- ── Cycle 2: dispatch goes to active state ────────────────────────────────────

test("keypressed dispatches to new state after switch, not old", function()
    local received = {}
    local state_a = { keypressed = function(_, k) received[#received + 1] = "a:" .. k end }
    local state_b = { keypressed = function(_, k) received[#received + 1] = "b:" .. k end }
    local sm = statemachine.new(state_a)
    sm:switch(state_b)
    sm:keypressed("left")
    eq(#received, 1,        "exactly one handler called")
    eq(received[1], "b:left", "new state received the key")
end)

-- ── Cycle 3: missing methods are no-ops ──────────────────────────────────────

test("switch does not crash when old state has no exit()", function()
    local state_a = {}  -- no exit
    local state_b = {}
    local sm = statemachine.new(state_a)
    sm:switch(state_b)  -- should not error
    eq(true, true, "no crash")
end)

test("update does not crash when active state has no update()", function()
    local sm = statemachine.new({})
    sm:update(0.016)
    eq(true, true, "no crash")
end)

-- ── Cycle 4: unknown calls forward to active state ────────────────────────────

test("machine:score() forwards to active state's score()", function()
    local state = { score = function() return 42 end }
    local sm = statemachine.new(state)
    eq(sm:score(), 42, "score forwarded from active state")
end)

test("machine:score() returns active state's value after switch", function()
    local state_a = { score = function() return 10 end }
    local state_b = { score = function() return 99 end }
    local sm = statemachine.new(state_a)
    eq(sm:score(), 10, "score from state_a")
    sm:switch(state_b)
    eq(sm:score(), 99, "score from state_b after switch")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
