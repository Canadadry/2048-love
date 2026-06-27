local menu        = require("menu")
local menu_screen = require("lib.menu_screen")
local transitions = require("lib.transitions")
local menu_sounds = require("menu_sounds")

local PUSH_BCK = transitions.push("right")
local T_DUR    = 0.25

local M = {}
local Screen = {}

function M.new(host, game)
    local self = setmetatable({ host = host, game = game }, { __index = Screen })
    self._mixin = menu_screen.new({
        items = {
            { label = "Resume",    on_activate = function() host:replace(game, PUSH_BCK, T_DUR) end },
            { label = "New Game",  on_activate = function() game:restart(); host:replace(game, PUSH_BCK, T_DUR) end },
            { label = "Main Menu", on_activate = function() host:replace(host:spawn("main_menu"), PUSH_BCK, T_DUR) end },
            { label = "Quit",      on_activate = function() host:quit() end },
        },
        on_select = menu_sounds.on_select,
    })
    return self
end

function Screen:enter()
    self._mixin:enter()
end

function Screen:cursor()
    return self._mixin:cursor()
end

function Screen:keypressed(key)
    if key == "escape" then
        self.host:replace(self.game, PUSH_BCK, T_DUR)
        return
    end
    self._mixin:keypressed(key)
end

function Screen:spec()
    return {
        title             = "Paused",
        title_font_offset = 8,
        bg_color          = menu.GAME_OVER_BG_COLOR,
        text_color        = menu.WHITE_COLOR,
        item_style        = "button",
        items             = self._mixin:items(),
    }
end

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), self:cursor(), function(i) self._mixin:tap(i) end, x, y)
end

function Screen:draw()
    menu.draw_menu(self:spec(), self:cursor())
end

return M
