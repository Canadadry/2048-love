local config   = require("config")
local settings = require("lib.settings")
local menu     = require("menu")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local fs_store

local function reset_fs()
    fs_store = {}
    love.filesystem.write        = function(path, contents) fs_store[path] = contents; return true end
    love.filesystem.read         = function(path) return fs_store[path] end
    love.filesystem.setIdentity  = function(_) end
end

love.window = { setTitle = function() end, setMode = function() end }
love.graphics.setBackgroundColor = function() end
love.graphics.setColor           = function(...) end
love.graphics.rectangle          = function(...) end
love.graphics.setFont            = function(...) end
love.graphics.print              = function(...) end
love.graphics.printf             = function(...) end
love.graphics.draw               = function(...) end
love.graphics.newCanvas          = function() return {} end
love.graphics.setCanvas          = function(...) end
love.graphics.setBlendMode       = function(...) end
love.graphics.clear              = function(...) end
love.graphics.newFont            = function(size)
    return {
        getWidth  = function(self, s) return #s * 7 end,
        getHeight = function(self) return 18 end,
        getWrap   = function(self, text, width) return 0, { text } end,
    }
end
love.graphics.newImage           = function(path)
    return { getPixelWidth = function() return 668 end, getPixelHeight = function() return 428 end }
end

local function with_restored_config(fn)
    local saved_win_tile          = config.WIN_TILE
    local saved_tileset           = config.TILESET
    local saved_animations        = config.ANIMATIONS_ENABLED
    local saved_effects           = config.EFFECTS_ENABLED
    local saved_music             = config.MUSIC.ENABLED
    fn()
    config.WIN_TILE           = saved_win_tile
    config.TILESET            = saved_tileset
    config.ANIMATIONS_ENABLED = saved_animations
    config.EFFECTS_ENABLED    = saved_effects
    config.MUSIC.ENABLED      = saved_music
end

-- ── Tracer bullet ─────────────────────────────────────────────────────────────

test("startup seeds config.WIN_TILE and config.TILESET from saved settings", function()
    with_restored_config(function()
        reset_fs()
        settings.set("win_tile", 32)
        settings.set("theme", "")
        arg = {}
        dofile("main.lua")
        love.load()
        eq(config.WIN_TILE, 32, "config.WIN_TILE seeded from saved settings")
    end)
end)

test("startup seeds config.ANIMATIONS_ENABLED and config.EFFECTS_ENABLED from saved settings", function()
    with_restored_config(function()
        reset_fs()
        settings.set("animations_enabled", false)
        settings.set("effects_enabled", false)
        arg = {}
        dofile("main.lua")
        love.load()
        eq(config.ANIMATIONS_ENABLED, false, "config.ANIMATIONS_ENABLED seeded from saved settings")
        eq(config.EFFECTS_ENABLED, false, "config.EFFECTS_ENABLED seeded from saved settings")
    end)
end)

test("startup seeds config.MUSIC.ENABLED from saved settings", function()
    with_restored_config(function()
        reset_fs()
        settings.set("music_enabled", false)
        arg = {}
        dofile("main.lua")
        love.load()
        eq(config.MUSIC.ENABLED, false, "config.MUSIC.ENABLED seeded from saved settings")
    end)
end)

-- ── CLI flag still wins ───────────────────────────────────────────────────────

test("--win-tile launch flag overrides a saved setting", function()
    with_restored_config(function()
        reset_fs()
        settings.set("win_tile", 2048)
        arg = { "--win-tile=32" }
        dofile("main.lua")
        love.load()
        eq(config.WIN_TILE, 32, "explicit launch flag takes priority over saved settings")
        arg = {}
    end)
end)

-- ── Mouse tap/swipe parity ───────────────────────────────────────────────────

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

local function setup_main_with_quit_stub()
    reset_fs()
    arg = {}
    dofile("main.lua")
    love.load()
    local quit_calls = 0
    love.event = { quit = function() quit_calls = quit_calls + 1 end }
    local stub_host = { replace = function() end, quit = function() end, spawn = function() return {} end }
    local mm_screen = require("screens.main_menu_screen").new(stub_host)
    local quit_btn = button_centers(menu.menu_tree(mm_screen:spec(), mm_screen:cursor(), nil))[3]
    return quit_btn, function() return quit_calls end
end

test("mouse-down alone over the Quit button does not fire it", function()
    local quit, quit_calls = setup_main_with_quit_stub()
    love.mousepressed(quit.x, quit.y, 1, false)
    eq(quit_calls(), 0, "mouse-down alone must not fire the button")
end)

test("mouse-down then release in place fires the Quit button once", function()
    local quit, quit_calls = setup_main_with_quit_stub()
    love.mousepressed(quit.x, quit.y, 1, false)
    love.mousereleased(quit.x, quit.y, 1, false)
    eq(quit_calls(), 1, "an ordinary click must still fire the button")
end)

test("mouse-down then drag-away release does not fire the Quit button", function()
    local quit, quit_calls = setup_main_with_quit_stub()
    love.mousepressed(quit.x, quit.y, 1, false)
    love.mousereleased(quit.x + 200, quit.y, 1, false)
    eq(quit_calls(), 0, "dragging away before release must cancel the tap")
end)

-- ── Full-graph wiring smoke test ─────────────────────────────────────────────

test("Main Menu -> New Game -> Pause -> Main Menu walk lands back on a fresh Main Menu", function()
    reset_fs()
    arg = {}
    dofile("main.lua")
    love.load()
    local quit_calls = 0
    love.event = { quit = function() quit_calls = quit_calls + 1 end }

    love.keypressed("return") -- Main Menu cursor 0 (New Game) -> replace with Game screen (animated)
    love.update(config.TRANSITION_DURATION + 0.1) -- drain main_menu->game transition
    love.keypressed("escape") -- Game -> replace with Pause (animated transition)
    love.update(config.TRANSITION_DURATION + 0.1) -- drain game->pause transition so Pause becomes current
    love.keypressed("down")   -- Pause cursor 0 -> 1 (New Game)
    love.keypressed("down")   -- Pause cursor 1 -> 2 (Main Menu)
    love.keypressed("return") -- Pause cursor 2 -> replace with a fresh Main Menu (animated)
    love.update(config.TRANSITION_DURATION + 0.1) -- drain pause->main_menu transition

    love.keypressed("down")   -- fresh Main Menu cursor 0 -> 1 (Options), proves cursor was reset
    love.keypressed("down")   -- Main Menu cursor 1 -> 2 (Quit)
    love.keypressed("return") -- Main Menu cursor 2 -> host:quit()

    eq(quit_calls, 1, "walking the whole graph and back must land on a freshly entered Main Menu")
end)

-- ── Raw mouse passthrough to the Game screen ─────────────────────────────────

test("swiping the board while the Game screen is focused reaches its own swipe handling, not the fallback tap-only swiper", function()
    reset_fs()
    arg = {}
    local original_random = math.random
    math.random = function(n) if n then return 1 else return 0 end end -- always first empty cell, always a 2

    dofile("main.lua")
    love.load()
    love.keypressed("return") -- Main Menu cursor 0 (New Game) -> replace with Game screen (animated)
    love.update(config.TRANSITION_DURATION + 0.1) -- drain transition so Game screen is current

    local tile_draw = require("tile_draw")
    local original_draw = tile_draw.draw
    local before, after

    tile_draw.draw = function(value, px, py, ...) before[#before + 1] = { value, px, py } end
    before = {}
    love.draw()

    love.mousepressed(400, 300, 1, false)
    love.mousemoved(140, 300, -260, 0, false) -- drag left, past the swipe threshold
    love.mousereleased(140, 300, 1, false)
    love.update(0)

    tile_draw.draw = function(value, px, py, ...) after[#after + 1] = { value, px, py } end
    after = {}
    love.draw()
    tile_draw.draw = original_draw
    math.random = original_random

    local changed = #before ~= #after
    if not changed then
        for i, cmd in ipairs(before) do
            if cmd[1] ~= after[i][1] or cmd[2] ~= after[i][2] or cmd[3] ~= after[i][3] then
                changed = true
                break
            end
        end
    end
    eq(changed, true,
        "a swipe gesture must reach the Game screen's own mousepressed/moved, " ..
        "since main.lua's fallback swiper only ever resolves taps, never directions")
end)

T.report()
