-- Run from: cd game && lua ../tests/test_all.lua
love = {
    graphics   = { getDimensions = function() return 600, 600 end },
    filesystem = {
        getDirectoryItems = function(_) return {} end,
        read              = function(_) return nil end,
        write             = function(_, _) return true end,
    },
}

local suites = {
    "../tests/test_grid.lua",
    "../tests/test_tile.lua",
    "../tests/test_particle.lua",
    "../tests/test_gamestate.lua",
    "../tests/test_tileset.lua",
    "../tests/test_swipe.lua",
    "../tests/test_pause.lua",
    "../tests/test_menu.lua",
    "../tests/test_main_menu.lua",
    "../tests/test_options.lua",
    "../tests/test_optionsmodel.lua",
    "../tests/test_settings.lua",
    "../tests/test_main.lua",
    "../tests/test_statemachine.lua",
    "../tests/test_screen_manager.lua",
    "../tests/test_options_screen.lua",
    "../tests/test_pause_screen.lua",
    "../tests/test_main_menu_screen.lua",
    "../tests/test_game_over_screen.lua",
    "../tests/test_win_screen.lua",
    "../tests/test_game_screen.lua",
    "../tests/test_renderer_board.lua",
    "../tests/test_renderer_tile_draw.lua",
    "../tests/test_renderer_hud.lua",
    -- runs last: replaces the global `love` stub wholesale, dropping
    -- love.filesystem, which settings.lua/tileset.lua need in earlier suites.
    "lib/ui/painter/painter_test.lua",
}

local real_exit = os.exit
local failed_suites = 0

os.exit = function(code)
    if (code or 0) ~= 0 then error("__suite_failed__") end
end

for _, path in ipairs(suites) do
    local ok, err = pcall(dofile, path)
    if not ok then
        if type(err) ~= "string" or not err:find("__suite_failed__") then
            print("ERROR in " .. path .. ": " .. tostring(err))
        end
        failed_suites = failed_suites + 1
    end
end

local total = #suites
print(string.format("\n=== %d/%d suites passed ===", total - failed_suites, total))
real_exit(failed_suites > 0 and 1 or 0)
