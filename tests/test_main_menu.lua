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

-- ── Tracer bullet ─────────────────────────────────────────────────────────────

test("new state starts in menu", function()
    local s = gamestate.new()
    eq(s:in_menu(), true, "in_menu() should be true on new state")
end)

-- ── Cursor navigation ─────────────────────────────────────────────────────────

test("down key moves cursor to 1 (Options)", function()
    local s = gamestate.new()
    s:keypressed("down")
    eq(s:menu_cursor(), 1, "cursor at 1 after down")
end)

test("down key clamps cursor at 2", function()
    local s = gamestate.new()
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("down")
    eq(s:menu_cursor(), 2, "cursor clamped at 2")
end)

test("up key clamps cursor at 0", function()
    local s = gamestate.new()
    s:keypressed("down")
    s:keypressed("up")
    eq(s:menu_cursor(), 0, "cursor back to 0")
    s:keypressed("up")
    eq(s:menu_cursor(), 0, "cursor clamped at 0")
end)

-- ── Enter actions ─────────────────────────────────────────────────────────────

test("enter with cursor=0 (New Game) exits menu", function()
    local s = gamestate.new()
    s:keypressed("return")
    eq(s:in_menu(), false, "should leave menu after Enter on New Game")
end)

test("enter with cursor=1 (Options) switches to options screen", function()
    local s = gamestate.new()
    s:keypressed("down")
    s:keypressed("return")
    eq(s:in_options(), true, "should enter options screen")
end)

test("enter with cursor=2 (Quit) sets quit_requested", function()
    local s = gamestate.new()
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("return")
    eq(s:quit_requested(), true, "quit_requested should be true")
end)

-- ── Tap selection (select_menu_item) ──────────────────────────────────────────

test("select_menu_item(0) starts new game even if cursor was elsewhere", function()
    local s = gamestate.new()
    s:keypressed("down")
    s:keypressed("down")
    s:select_menu_item(0)
    eq(s:in_menu(), false, "should leave menu after selecting New Game")
end)

test("select_menu_item(1) enters options even if cursor was elsewhere", function()
    local s = gamestate.new()
    s:keypressed("down")
    s:keypressed("down")
    s:select_menu_item(1)
    eq(s:in_options(), true, "should enter options screen")
end)

test("select_menu_item(2) requests quit even if cursor was elsewhere", function()
    local s = gamestate.new()
    s:select_menu_item(2)
    eq(s:quit_requested(), true, "quit_requested should be true")
end)

-- ── Keys ignored while in menu ────────────────────────────────────────────────

test("game direction keys are ignored while in menu", function()
    local s = gamestate.new()
    s:keypressed("left")
    eq(s:in_menu(), true, "still in menu after left arrow")
end)

test("escape is ignored while in menu", function()
    local s = gamestate.new()
    s:keypressed("escape")
    eq(s:in_menu(), true, "still in menu after escape")
    eq(s:paused(), false, "not paused")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
