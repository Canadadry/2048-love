local config       = require("config")
local i18n         = require("lib.i18n")
local menu_screen  = require("lib.menu_screen")
local menu         = require("menu")
local transitions  = require("lib.transitions")
local menu_sounds  = require("menu_sounds")
local music        = require("lib.music")

local PUSH_FWD = transitions.push("left")
local T_DUR    = config.TRANSITION_DURATION

local _logo
local function get_logo()
    if not _logo then _logo = love.graphics.newImage("assets/logo.png") end
    return _logo
end

local M = {}
local Screen = {}

function M.new(host)
    local self = setmetatable({ host = host }, { __index = Screen })
    self._mixin = menu_screen.new({
        items = {
            { label = i18n.t("menu.new_game"), on_activate = function() host:replace(host:spawn("loading"), PUSH_FWD, T_DUR) end },
            { label = i18n.t("screen.options"), on_activate = function() host:replace(host:spawn("options"), PUSH_FWD, T_DUR) end },
            { label = i18n.t("menu.quit"),     on_activate = function() host:quit() end },
        },
        on_select = menu_sounds.on_select,
    })
    return self
end

function Screen:enter()
    music.play(config.MUSIC.MENU)
    self._mixin:enter()
end

function Screen:cursor()
    return self._mixin:cursor()
end

function Screen:keypressed(key)
    self._mixin:keypressed(key)
end

function Screen:spec()
    return { logo = get_logo(), bg_color = menu.BG_COLOR, item_style = "button", items = self._mixin:items() }
end

function Screen:draw()
    menu.draw_menu(self:spec(), self:cursor())
end

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), self:cursor(), function(i) self._mixin:tap(i) end, x, y)
end

return M
