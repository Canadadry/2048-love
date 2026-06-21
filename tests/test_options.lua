function love.filesystem.getDirectoryItems(_)
    return { "jurassic-park.lua", "jurassic-park.png" }
end

local gamestate = require("gamestate")
local config    = require("config")

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

-- ── Theme switcher ────────────────────────────────────────────────────────────

test("entering options lists None plus available themes, cursor on active theme", function()
    config.TILESET = ""
    local s = in_options()
    local names = s:tileset_names()
    eq(names[1], "", "None sentinel first")
    eq(names[2], "jurassic-park", "available theme listed")
    eq(s:tileset_cursor(), 1, "cursor defaults to active theme (None)")
end)

test("down/up moves the theme cursor, clamped at both ends", function()
    config.TILESET = ""
    local s = in_options()
    eq(s:tileset_cursor(), 1, "starts at None")
    s:keypressed("up")
    eq(s:tileset_cursor(), 1, "clamped at top")
    s:keypressed("down")
    eq(s:tileset_cursor(), 2, "moves to jurassic-park")
    s:keypressed("down")
    eq(s:tileset_cursor(), 2, "clamped at bottom (only 2 entries)")
    s:keypressed("up")
    eq(s:tileset_cursor(), 1, "moves back to None")
end)

test("return on a theme entry sets it as the active tileset", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("down")
    s:keypressed("return")
    eq(config.TILESET, "jurassic-park", "active tileset confirmed")
    config.TILESET = ""
end)

test("return on None sets the active tileset back to classic rendering", function()
    config.TILESET = "jurassic-park"
    local s = in_options()
    eq(s:tileset_cursor(), 2, "cursor starts on the active theme")
    s:keypressed("up")
    s:keypressed("return")
    eq(config.TILESET, "", "active tileset cleared to None")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
