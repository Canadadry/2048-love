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

local function in_options()
    local s = gamestate.new()
    s:keypressed("down")
    s:keypressed("return")
    return s
end

-- ── Tracer bullet ─────────────────────────────────────────────────────────────

test("escape from options returns to menu", function()
    local s = in_options()
    s:keypressed("escape")
    eq(s:in_menu(), true, "should be back in menu")
    eq(s:in_options(), false, "should have left options")
end)

-- ── Win tile toggle ───────────────────────────────────────────────────────────

test("win_tile defaults to 2048", function()
    local s = in_options()
    eq(s:win_tile(), 2048, "default win tile is 2048")
end)

test("right arrow in options toggles win_tile to 32", function()
    local s = in_options()
    s:keypressed("right")
    eq(s:win_tile(), 32, "win tile toggled to 32 (dev mode)")
    s:keypressed("right")
    eq(s:win_tile(), 2048, "win tile toggled back to 2048 (prod mode)")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
