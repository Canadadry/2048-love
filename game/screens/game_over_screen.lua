local menu        = require("menu")
local menu_screen = require("menu_screen")

local M = {}
local Screen = {}

local DIRS = { left = true, right = true, up = true, down = true }

function M.new(host, game)
    local self = setmetatable({ host = host, game = game }, { __index = Screen })
    self._mixin = menu_screen.new({
        items = {
            { label = "New Game", on_activate = function() game:restart(); host:dismiss() end },
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
    if key == "return" or DIRS[key] then
        self._mixin:keypressed("return")
        return
    end
    self._mixin:keypressed(key)
end

function Screen:spec()
    return {
        title             = "Game Over",
        title_font_offset = 8,
        bg_color          = menu.GAME_OVER_BG_COLOR,
        text_color        = menu.WHITE_COLOR,
        item_style        = "button",
        btn_w_ratio       = 0.4,
        items             = self._mixin:items(),
    }
end

-- Game Over's lone button is never drawn as "selected" (no cursor highlight,
-- matching the pre-refactor behavior); -1 never matches a 0-based item index.
local UNSELECTED = -1

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), UNSELECTED, function(i) self._mixin:tap(i) end, x, y)
end

function Screen:draw()
    menu.draw_menu(self:spec(), UNSELECTED)
end

function Screen:opaque()
    return false
end

return M
