love = {
    graphics   = {
        getDimensions = function() return 600, 600 end,
        newFont = function(size)
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 18 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
    },
    filesystem = {
        getDirectoryItems = function(_) return {} end,
        read              = function(_) return nil end,
        write             = function(_, _) return true end,
    },
}
local menu = require("menu")

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

local function positive_finite(v, label)
    if type(v) ~= "number" or v <= 0 or v ~= v then
        error(label .. " must be a positive finite number, got " .. tostring(v), 2)
    end
end

test("pause_button_bounds returns 4 buttons with positive finite dimensions", function()
    local btns = menu.pause_button_bounds()
    if #btns ~= 4 then error("expected 4 buttons, got " .. #btns) end
    for i, b in ipairs(btns) do
        local pfx = "button[" .. i .. "]."
        positive_finite(b.x, pfx .. "x")
        positive_finite(b.y, pfx .. "y")
        positive_finite(b.w, pfx .. "w")
        positive_finite(b.h, pfx .. "h")
    end
end)

test("pause_button_bounds button labels are Resume, New Game, Main Menu, Quit", function()
    local btns = menu.pause_button_bounds()
    if btns[1].label ~= "Resume"    then error("button 1 label: " .. tostring(btns[1].label)) end
    if btns[2].label ~= "New Game"  then error("button 2 label: " .. tostring(btns[2].label)) end
    if btns[3].label ~= "Main Menu" then error("button 3 label: " .. tostring(btns[3].label)) end
    if btns[4].label ~= "Quit"      then error("button 4 label: " .. tostring(btns[4].label)) end
end)

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

test("main_menu_hit_test routes taps to the right callback, and a miss fires none", function()
    local centers = button_centers(menu.main_menu_tree(0, {}))
    if #centers ~= 3 then error("expected 3 buttons, got " .. #centers) end

    local fired
    local callbacks = {
        on_new_game = function() fired = "new_game" end,
        on_options  = function() fired = "options" end,
        on_quit     = function() fired = "quit" end,
    }

    fired = nil
    menu.main_menu_hit_test(0, callbacks, centers[1].x, centers[1].y)
    if fired ~= "new_game" then error("expected new_game, got " .. tostring(fired)) end

    fired = nil
    menu.main_menu_hit_test(0, callbacks, centers[2].x, centers[2].y)
    if fired ~= "options" then error("expected options, got " .. tostring(fired)) end

    fired = nil
    menu.main_menu_hit_test(0, callbacks, centers[3].x, centers[3].y)
    if fired ~= "quit" then error("expected quit, got " .. tostring(fired)) end

    fired = nil
    menu.main_menu_hit_test(0, callbacks, 5, 5)
    if fired ~= nil then error("expected no callback to fire on a miss, got " .. tostring(fired)) end
end)

test("win_hit_test routes taps to continue/restart, and a miss fires none", function()
    local centers = button_centers(menu.win_tree(0, {}))
    if #centers ~= 2 then error("expected 2 buttons, got " .. #centers) end

    local fired
    local callbacks = {
        on_continue = function() fired = "continue" end,
        on_restart  = function() fired = "restart" end,
    }

    fired = nil
    menu.win_hit_test(0, callbacks, centers[1].x, centers[1].y)
    if fired ~= "continue" then error("expected continue, got " .. tostring(fired)) end

    fired = nil
    menu.win_hit_test(0, callbacks, centers[2].x, centers[2].y)
    if fired ~= "restart" then error("expected restart, got " .. tostring(fired)) end

    fired = nil
    menu.win_hit_test(0, callbacks, 5, 5)
    if fired ~= nil then error("expected no callback to fire on a miss, got " .. tostring(fired)) end
end)

test("game_over_hit_test routes a tap to restart, and a miss fires none", function()
    local centers = button_centers(menu.game_over_tree({}))
    if #centers ~= 1 then error("expected 1 button, got " .. #centers) end

    local fired
    local callbacks = { on_restart = function() fired = "restart" end }

    fired = nil
    menu.game_over_hit_test(callbacks, centers[1].x, centers[1].y)
    if fired ~= "restart" then error("expected restart, got " .. tostring(fired)) end

    fired = nil
    menu.game_over_hit_test(callbacks, 5, 5)
    if fired ~= nil then error("expected no callback to fire on a miss, got " .. tostring(fired)) end
end)

local function interactive_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and (cmd.painter.kind == "Group" or cmd.painter.kind == "Interactive") then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

test("options_hit_test routes a tap to the matching row index, and a miss fires none", function()
    local centers = interactive_centers(menu.options_tree(2048, "", true, true, 1, {}))
    if #centers ~= 5 then error("expected 4 rows + 1 back button, got " .. #centers) end

    local tapped
    local callbacks = { on_row_tap = function(i) tapped = i end }

    for i = 1, 4 do
        tapped = nil
        menu.options_hit_test(2048, "", true, true, 1, callbacks, centers[i].x, centers[i].y)
        if tapped ~= i then error("expected row " .. i .. ", got " .. tostring(tapped)) end
    end

    tapped = nil
    menu.options_hit_test(2048, "", true, true, 1, callbacks, 5, 5)
    if tapped ~= nil then error("expected no callback to fire on a miss, got " .. tostring(tapped)) end
end)

test("options_hit_test routes a tap on the Back button to on_back", function()
    local centers = interactive_centers(menu.options_tree(2048, "", true, true, 1, {}))
    local back_center = centers[#centers]

    local fired
    local callbacks = { on_back = function() fired = true end }

    menu.options_hit_test(2048, "", true, true, 1, callbacks, back_center.x, back_center.y)
    if fired ~= true then error("expected on_back to fire") end
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
