love = {
    graphics   = {
        getDimensions = function() return 600, 600 end,
        newFont       = function(size)
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 18 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
        setColor  = function(...) end,
        rectangle = function(...) end,
        draw      = function(...) end,
        printf    = function(...) end,
        setFont   = function(...) end,
    },
    filesystem = {
        getDirectoryItems = function(_) return { "jurassic-park.lua", "jurassic-park.png" } end,
        read              = function(_) return nil end,
        write             = function(_, _) return true end,
    },
}

local options_screen = require("screens.options_screen")
local config         = require("config")
local settings       = require("settings")

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

local function stub_host()
    return { dismiss_count = 0, dismiss = function(self) self.dismiss_count = self.dismiss_count + 1 end }
end

local function new_screen()
    local host = stub_host()
    local screen = options_screen.new(host)
    screen:enter()
    return screen, host
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("escape calls host:dismiss()", function()
    local screen, host = new_screen()
    screen:keypressed("escape")
    eq(host.dismiss_count, 1, "escape must dismiss the options screen")
end)

-- ── Cycle 2: enter() defaults focus to the first row ─────────────────────────

test("entering options defaults focus to the first row (Win Tile)", function()
    local screen = new_screen()
    eq(screen:focused_row(), 1, "focus starts on Win Tile")
end)

-- ── Cycle 3: up/down move focus, wrapping ────────────────────────────────────

test("down/up move focus between rows, wrapping at both ends", function()
    local screen = new_screen()
    screen:keypressed("down")
    eq(screen:focused_row(), 2, "down moves focus to Theme")
    screen:keypressed("down")
    eq(screen:focused_row(), 3, "down moves focus to Animations")
    screen:keypressed("down")
    eq(screen:focused_row(), 4, "down moves focus to Effects")
    screen:keypressed("down")
    eq(screen:focused_row(), 5, "down moves focus to Back")
    screen:keypressed("down")
    eq(screen:focused_row(), 1, "down wraps from Back back to Win Tile")
    screen:keypressed("up")
    eq(screen:focused_row(), 5, "up wraps from Win Tile to Back")
end)

-- ── Cycle 4: left/right on Win Tile toggles + persists config.WIN_TILE ───────

test("left/right on the Win Tile row toggle config.WIN_TILE immediately, without affecting focus or Theme", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("right")
    eq(config.WIN_TILE, 32, "win tile toggled to 32 (dev mode)")
    eq(screen:focused_row(), 1, "focus stays on Win Tile")
    eq(config.TILESET, "", "Theme untouched by Win Tile toggling")
    screen:keypressed("left")
    eq(config.WIN_TILE, 2048, "win tile toggled back to 2048 (prod mode)")
end)

test("toggling Win Tile persists the new value via settings.set", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("right")
    eq(settings.get("win_tile", nil), 32, "win_tile persisted on toggle")
    screen:keypressed("left")
end)

-- ── Cycle 5: left/right on Theme cycles + persists config.TILESET ────────────

test("left/right on the Theme row cycle config.TILESET through available themes, wrapping, applied immediately", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("down")
    eq(screen:focused_row(), 2, "focus on Theme")
    screen:keypressed("right")
    eq(config.TILESET, "jurassic-park", "theme advanced without needing return")
    screen:keypressed("right")
    eq(config.TILESET, "", "theme wraps back to None sentinel")
    screen:keypressed("left")
    eq(config.TILESET, "jurassic-park", "left wraps backward to the last theme")
    config.TILESET = ""
end)

test("cycling Theme persists the new value via settings.set", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("theme", nil), "jurassic-park", "theme persisted on cycle")
    config.TILESET = ""
end)

-- ── Cycle 6: left/right on Animations/Effects toggles + persists ────────────

test("left/right on the Animations row toggles config.ANIMATIONS_ENABLED, applied immediately", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:focused_row(), 3, "focus on Animations")
    screen:keypressed("right")
    eq(config.ANIMATIONS_ENABLED, false, "animations toggled off")
    screen:keypressed("left")
    eq(config.ANIMATIONS_ENABLED, true, "animations toggled back on")
end)

test("toggling Animations persists the new value via settings.set", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("animations_enabled", nil), false, "animations_enabled persisted on toggle")
    screen:keypressed("left")
end)

test("left/right on the Effects row toggles config.EFFECTS_ENABLED, applied immediately", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:focused_row(), 4, "focus on Effects")
    screen:keypressed("right")
    eq(config.EFFECTS_ENABLED, false, "effects toggled off")
    screen:keypressed("left")
    eq(config.EFFECTS_ENABLED, true, "effects toggled back on")
end)

test("toggling Effects persists the new value via settings.set", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("effects_enabled", nil), false, "effects_enabled persisted on toggle")
    screen:keypressed("left")
end)

-- ── Cycle 7: left/right on the Back row is inert ─────────────────────────────

test("left/right on the Back row change nothing observable", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:focused_row(), 5, "focus on Back")
    local settings_before = settings.get("effects_enabled", nil)
    screen:keypressed("right")
    eq(screen:focused_row(), 5, "focus unchanged by right")
    eq(config.EFFECTS_ENABLED, true, "no row's config mutated by right on Back")
    eq(settings.get("effects_enabled", nil), settings_before, "no settings write from right on Back")
    screen:keypressed("left")
    eq(screen:focused_row(), 5, "focus unchanged by left")
    eq(config.EFFECTS_ENABLED, true, "no row's config mutated by left on Back")
end)

test("left/right on the Back row never calls settings.set", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:focused_row(), 5, "focus on Back")
    local calls = 0
    local real_set = settings.set
    settings.set = function(...) calls = calls + 1; return real_set(...) end
    screen:keypressed("right")
    screen:keypressed("left")
    settings.set = real_set
    eq(calls, 0, "settings.set must not be called for the Back row")
end)

-- ── Cycle 8: tap_row focus-then-activate semantics ───────────────────────────

test("tapping an unfocused row focuses it without changing its value", function()
    local screen = new_screen()
    screen:tap_row(2)
    eq(screen:focused_row(), 2, "tap focuses the Theme row")
    eq(config.WIN_TILE, 2048, "Win Tile value unchanged by a focus-only tap")
end)

test("tapping the already-focused row cycles its value forward, like right()", function()
    local screen = new_screen()
    screen:tap_row(2)                  -- move focus off Win Tile first
    screen:tap_row(1)                  -- focus-only tap: lands on Win Tile, no cycle
    eq(screen:focused_row(), 1, "now focused on Win Tile")
    eq(config.WIN_TILE, 2048, "focus-only tap left the value untouched")
    screen:tap_row(1)                  -- second tap: row already focused, cycles
    eq(config.WIN_TILE, 32, "second tap on the focused row cycles the value forward")
    screen:tap_row(1)                  -- revert
end)

test("tapping the already-focused Win Tile row persists the new value via settings.set", function()
    local screen = new_screen()
    screen:tap_row(2)
    screen:tap_row(1)
    screen:tap_row(1)
    eq(settings.get("win_tile", nil), 32, "win_tile persisted on tap-cycle")
    screen:tap_row(1)                  -- revert
end)

-- ── Cycle 9: tap_row on Back / return on Back dismiss ────────────────────────

test("tapping the Back row twice (focus, then activate) calls host:dismiss() once", function()
    local screen, host = new_screen()
    screen:tap_row(5)
    eq(screen:focused_row(), 5, "first tap focuses Back")
    eq(host.dismiss_count, 0, "still on options after focus-only tap")
    screen:tap_row(5)
    eq(host.dismiss_count, 1, "second tap on focused Back dismisses")
end)

test("return has no observable effect on the Options screen, except when Back is focused", function()
    config.TILESET = ""
    local screen, host = new_screen()
    screen:keypressed("return")
    eq(host.dismiss_count, 0, "return does not dismiss when Back isn't focused")
    eq(screen:focused_row(), 1, "focus unchanged by return")
    eq(config.WIN_TILE, 2048, "win tile unchanged by return")
    eq(config.TILESET, "", "theme unchanged by return")
end)

test("return while Back is focused calls host:dismiss()", function()
    local screen, host = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:focused_row(), 5, "focus on Back")
    screen:keypressed("return")
    eq(host.dismiss_count, 1, "return on Back dismisses")
end)

-- ── Cycle 10: draw() delegates to menu.draw_options ──────────────────────────

test("draw() runs without erroring", function()
    local screen = new_screen()
    screen:draw()
    eq(true, true, "no crash")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
