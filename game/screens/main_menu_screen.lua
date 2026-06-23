local menu_screen = require("lib.menu_screen")
local menu        = require("menu")

local M = {}
local Screen = {}

function M.new(host)
    local self = setmetatable({ host = host }, { __index = Screen })
    self._mixin = menu_screen.new({
        items = {
            { label = "New Game", on_activate = function() host:replace(host:spawn("game")) end },
            { label = "Options",  on_activate = function() host:promote(host:spawn("options")) end },
            { label = "Quit",     on_activate = function() host:quit() end },
        },
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
    self._mixin:keypressed(key)
end

function Screen:spec()
    return { title = "2048", bg_color = menu.BG_COLOR, item_style = "button", items = self._mixin:items() }
end

function Screen:draw()
    menu.draw_menu(self:spec(), self:cursor())
end

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), self:cursor(), function(i) self._mixin:tap(i) end, x, y)
end

return M
