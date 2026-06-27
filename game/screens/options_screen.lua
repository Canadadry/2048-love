local config       = require("config")
local tileset      = require("tileset")
local optionsmodel = require("lib.optionsmodel")
local settings     = require("lib.settings")
local menu         = require("menu")
local menu_screen  = require("lib.menu_screen")
local transitions  = require("lib.transitions")
local menu_sounds  = require("menu_sounds")

local PUSH_BCK = transitions.push("right")
local T_DUR    = config.TRANSITION_DURATION

local BOOLEAN_VALUES = { true, false }

local function theme_label(name)
    return name == "" and "None (classic)" or name
end

local function bool_label(enabled)
    return enabled and "ON" or "OFF"
end

local M = {}
local Screen = {}

function M.new(host)
    return setmetatable({ host = host }, { __index = Screen })
end

local function value_row(label, values, get, set, format)
    format = format or tostring
    local item = { label = label, value = format(get()) }
    local function cycle(step)
        local v = step(values, get())
        set(v)
        item.value = format(v)
    end
    item.on_left  = function() cycle(optionsmodel.prev) end
    item.on_right = function() cycle(optionsmodel.next) end
    return item
end

function Screen:enter()
    local host = self.host
    local win_tile_values = { 16, 2048 }
    local theme_values    = tileset.list_available()

    local items = {
        value_row("Win Tile", win_tile_values,
            function() return config.WIN_TILE end,
            function(v) config.WIN_TILE = v; settings.set("win_tile", v) end),
        value_row("Theme", theme_values,
            function() return config.TILESET end,
            function(v) config.TILESET = v; settings.set("theme", v) end,
            theme_label),
        value_row("Animations", BOOLEAN_VALUES,
            function() return config.ANIMATIONS_ENABLED end,
            function(v) config.ANIMATIONS_ENABLED = v; settings.set("animations_enabled", v) end,
            bool_label),
        value_row("Effects", BOOLEAN_VALUES,
            function() return config.EFFECTS_ENABLED end,
            function(v) config.EFFECTS_ENABLED = v; settings.set("effects_enabled", v) end,
            bool_label),
        value_row("Sound", BOOLEAN_VALUES,
            function() return config.SOUND.ENABLED end,
            function(v) config.SOUND.ENABLED = v; settings.set("sound_enabled", v) end,
            bool_label),
        { label = "Up/Down to focus a row, Left/Right to change its value, or tap a row", focusable = false },
        { label = "Back", on_activate = function() host:replace(host:spawn("main_menu"), PUSH_BCK, T_DUR) end, focus_before_activate = true },
    }

    self._mixin = menu_screen.new({ items = items, wrap = true, on_select = menu_sounds.on_select, on_change = menu_sounds.on_change })
end

function Screen:cursor()
    return self._mixin:cursor()
end

function Screen:keypressed(key)
    if key == "escape" then
        self.host:replace(self.host:spawn("main_menu"), PUSH_BCK, T_DUR)
        return
    end
    self._mixin:keypressed(key)
end

function Screen:spec()
    return { title = "Options", bg_color = menu.BG_COLOR, item_style = "row", items = self._mixin:items() }
end

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), self:cursor(), function(i) self._mixin:tap(i) end, x, y)
end

function Screen:draw()
    menu.draw_menu(self:spec(), self:cursor())
end

return M
