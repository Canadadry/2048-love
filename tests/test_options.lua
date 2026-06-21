function love.filesystem.getDirectoryItems(_)
    return { "jurassic-park.lua", "jurassic-park.png" }
end

local gamestate = require("gamestate")
local config    = require("config")
local settings  = require("settings")

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

-- ── Row focus ─────────────────────────────────────────────────────────────────

test("entering options defaults focus to the first row (Win Tile)", function()
    local s = in_options()
    eq(s:focused_row(), 1, "focus starts on Win Tile")
end)

test("down/up move focus between rows, wrapping at both ends", function()
    local s = in_options()
    s:keypressed("down")
    eq(s:focused_row(), 2, "down moves focus to Theme")
    s:keypressed("down")
    eq(s:focused_row(), 1, "down wraps from Theme back to Win Tile")
    s:keypressed("up")
    eq(s:focused_row(), 2, "up wraps from Win Tile to Theme")
end)

-- ── Win tile toggle ───────────────────────────────────────────────────────────

test("win_tile defaults to 2048", function()
    local s = in_options()
    eq(s:win_tile(), 2048, "default win tile is 2048")
end)

test("left/right on the Win Tile row toggle config.WIN_TILE immediately, without affecting focus or Theme", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("right")
    eq(s:win_tile(), 32, "win tile toggled to 32 (dev mode)")
    eq(s:focused_row(), 1, "focus stays on Win Tile")
    eq(config.TILESET, "", "Theme untouched by Win Tile toggling")
    s:keypressed("left")
    eq(s:win_tile(), 2048, "win tile toggled back to 2048 (prod mode)")
end)

-- ── Theme switcher ────────────────────────────────────────────────────────────

test("left/right on the Theme row cycle config.TILESET through available themes, wrapping, applied immediately", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("down")
    eq(s:focused_row(), 2, "focus on Theme")
    s:keypressed("right")
    eq(config.TILESET, "jurassic-park", "theme advanced without needing return")
    s:keypressed("right")
    eq(config.TILESET, "", "theme wraps back to None sentinel")
    s:keypressed("left")
    eq(config.TILESET, "jurassic-park", "left wraps backward to the last theme")
    config.TILESET = ""
end)

-- ── Settings persistence ──────────────────────────────────────────────────────

test("toggling Win Tile persists the new value via settings.set", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("right")
    eq(settings.get("win_tile", nil), 32, "win_tile persisted on toggle")
    s:keypressed("left")
end)

test("cycling Theme persists the new value via settings.set", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("down")
    s:keypressed("right")
    eq(settings.get("theme", nil), "jurassic-park", "theme persisted on cycle")
    config.TILESET = ""
end)

-- ── Enter is a no-op ──────────────────────────────────────────────────────────

test("return has no observable effect on the Options screen", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("return")
    eq(s:in_options(), true, "still in options")
    eq(s:focused_row(), 1, "focus unchanged by return")
    eq(s:win_tile(), 2048, "win tile unchanged by return")
    eq(config.TILESET, "", "theme unchanged by return")
end)

-- ── Escape always returns to menu ─────────────────────────────────────────────

test("escape returns to the main menu regardless of which row has focus", function()
    local s = in_options()
    s:keypressed("down")
    s:keypressed("escape")
    eq(s:in_menu(), true, "should be back in menu even with Theme focused")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
