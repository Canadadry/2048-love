local config      = require("config")
local i18n        = require("lib.i18n")
local menu        = require("menu")
local menu_screen = require("lib.menu_screen")
local transitions = require("lib.transitions")
local menu_sounds = require("menu_sounds")
local music       = require("lib.music")

local PUSH_BCK = transitions.push("right")
local T_DUR    = config.TRANSITION_DURATION

local M = {}
local Screen = {}

local DIRS = { left = true, right = true, up = true, down = true }

function M.new(host, game)
    local self = setmetatable({ host = host, game = game }, { __index = Screen })
    self._mixin = menu_screen.new({
        items = {
            { label = i18n.t("menu.new_game"),  on_activate = function() game:restart(); host:replace(game, PUSH_BCK, T_DUR) end },
            { label = i18n.t("menu.main_menu"), on_activate = function() host:replace(host:spawn("main_menu"), PUSH_BCK, T_DUR) end },
        },
        on_select = menu_sounds.on_select,
    })
    return self
end

function Screen:enter()
    music.play(config.MUSIC.GAME)
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
        title             = i18n.t("screen.game_over"),
        title_font_offset = 8,
        bg_color          = menu.BG_COLOR,
        text_color        = menu.WHITE_COLOR,
        item_style        = "button",
        btn_w_ratio       = 0.4,
        items             = self._mixin:items(),
    }
end

-- Game Over's buttons are never drawn as "selected" (no cursor highlight);
-- -1 never matches a 0-based item index.
local UNSELECTED = -1

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), UNSELECTED, function(i) self._mixin:tap(i) end, x, y)
end

function Screen:draw()
    menu.draw_menu(self:spec(), UNSELECTED)
end


return M
