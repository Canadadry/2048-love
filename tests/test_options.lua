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
    eq(s:focused_row(), 3, "down moves focus to Animations")
    s:keypressed("down")
    eq(s:focused_row(), 4, "down moves focus to Effects")
    s:keypressed("down")
    eq(s:focused_row(), 5, "down moves focus to Back")
    s:keypressed("down")
    eq(s:focused_row(), 1, "down wraps from Back back to Win Tile")
    s:keypressed("up")
    eq(s:focused_row(), 5, "up wraps from Win Tile to Back")
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

-- ── Animations toggle ─────────────────────────────────────────────────────────

test("animations_enabled defaults to true", function()
    local s = in_options()
    eq(s:animations_enabled(), true, "default animations_enabled is true")
end)

test("left/right on the Animations row toggles config.ANIMATIONS_ENABLED, applied immediately", function()
    local s = in_options()
    s:keypressed("down")
    s:keypressed("down")
    eq(s:focused_row(), 3, "focus on Animations")
    s:keypressed("right")
    eq(s:animations_enabled(), false, "animations toggled off")
    s:keypressed("left")
    eq(s:animations_enabled(), true, "animations toggled back on")
end)

-- ── Effects toggle ────────────────────────────────────────────────────────────

test("effects_enabled defaults to true", function()
    local s = in_options()
    eq(s:effects_enabled(), true, "default effects_enabled is true")
end)

test("left/right on the Effects row toggles config.EFFECTS_ENABLED, applied immediately", function()
    local s = in_options()
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("down")
    eq(s:focused_row(), 4, "focus on Effects")
    s:keypressed("right")
    eq(s:effects_enabled(), false, "effects toggled off")
    s:keypressed("left")
    eq(s:effects_enabled(), true, "effects toggled back on")
end)

-- ── Back row ──────────────────────────────────────────────────────────────────

test("left/right on the Back row change nothing observable", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("down")
    eq(s:focused_row(), 5, "focus on Back")
    local settings_before = settings.get("effects_enabled", nil)
    s:keypressed("right")
    eq(s:focused_row(), 5, "focus unchanged by right")
    eq(s:effects_enabled(), true, "no row's config mutated by right on Back")
    eq(settings.get("effects_enabled", nil), settings_before, "no settings write from right on Back")
    s:keypressed("left")
    eq(s:focused_row(), 5, "focus unchanged by left")
    eq(s:effects_enabled(), true, "no row's config mutated by left on Back")
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

test("toggling Animations persists the new value via settings.set", function()
    local s = in_options()
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("right")
    eq(settings.get("animations_enabled", nil), false, "animations_enabled persisted on toggle")
    s:keypressed("left")
end)

test("toggling Effects persists the new value via settings.set", function()
    local s = in_options()
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("right")
    eq(settings.get("effects_enabled", nil), false, "effects_enabled persisted on toggle")
    s:keypressed("left")
end)

-- ── Tap a row ─────────────────────────────────────────────────────────────────

test("tapping an unfocused row focuses it without changing its value", function()
    local s = in_options()
    s:tap_row(2)
    eq(s:focused_row(), 2, "tap focuses the Theme row")
    eq(s:win_tile(), 2048, "Win Tile value unchanged by a focus-only tap")
end)

test("tapping the already-focused row cycles its value forward, like right()", function()
    local s = in_options()
    s:tap_row(2)                  -- move focus off Win Tile first
    s:tap_row(1)                  -- focus-only tap: lands on Win Tile, no cycle
    eq(s:focused_row(), 1, "now focused on Win Tile")
    eq(s:win_tile(), 2048, "focus-only tap left the value untouched")
    s:tap_row(1)                  -- second tap: row already focused, cycles
    eq(s:win_tile(), 32, "second tap on the focused row cycles the value forward")
    s:tap_row(1)                  -- revert
end)

test("tapping the already-focused Win Tile row persists the new value via settings.set", function()
    local s = in_options()
    s:tap_row(2)
    s:tap_row(1)
    s:tap_row(1)
    eq(settings.get("win_tile", nil), 32, "win_tile persisted on tap-cycle")
    s:tap_row(1)                  -- revert
end)

test("tapping the Back row twice (focus, then activate) returns to the Main Menu", function()
    local s = in_options()
    s:tap_row(5)
    eq(s:focused_row(), 5, "first tap focuses Back")
    eq(s:in_options(), true, "still in options after focus-only tap")
    s:tap_row(5)
    eq(s:in_menu(), true, "second tap on focused Back returns to menu")
end)

-- ── Enter is a no-op ──────────────────────────────────────────────────────────

test("return has no observable effect on the Options screen, except when Back is focused", function()
    config.TILESET = ""
    local s = in_options()
    s:keypressed("return")
    eq(s:in_options(), true, "still in options")
    eq(s:focused_row(), 1, "focus unchanged by return")
    eq(s:win_tile(), 2048, "win tile unchanged by return")
    eq(config.TILESET, "", "theme unchanged by return")
end)

test("return while Back is focused returns to the Main Menu", function()
    local s = in_options()
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("down")
    s:keypressed("down")
    eq(s:focused_row(), 5, "focus on Back")
    s:keypressed("return")
    eq(s:in_menu(), true, "return on Back returns to menu")
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
