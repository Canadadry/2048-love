local config       = require("config")
local i18n         = require("lib.i18n")
local tileset      = require("tileset")
local optionsmodel = require("lib.optionsmodel")
local settings     = require("lib.settings")
local menu         = require("menu")
local menu_screen  = require("lib.menu_screen")
local transitions  = require("lib.transitions")
local menu_sounds  = require("menu_sounds")
local music        = require("lib.music")

local PUSH_BCK = transitions.push("right")
local T_DUR    = config.TRANSITION_DURATION

local BOOLEAN_VALUES = { true, false }

local function theme_label(name)
    return name == "" and i18n.t("options.theme_none") or name
end

local function bool_label(enabled)
    return enabled and i18n.t("options.on") or i18n.t("options.off")
end

local M = {}
local Screen = {}

function M.new(host)
    return setmetatable({ host = host }, { __index = Screen })
end

local function value_row(label_fn, values, get, set, format)
    format = format or tostring
    local value_fn = function() return format(get()) end
    local item = { label = label_fn(), _label_fn = label_fn, value = value_fn(), _value_fn = value_fn }
    local function cycle(step)
        local v = step(values, get())
        set(v)
        item.value = format(v)
    end
    item.on_left  = function() cycle(optionsmodel.prev) end
    item.on_right = function() cycle(optionsmodel.next) end
    return item
end

local function refresh_items(items)
    for _, item in ipairs(items) do
        if item._label_fn then item.label = item._label_fn() end
        if item._value_fn then item.value = item._value_fn() end
    end
end

function Screen:enter()
    music.play(config.MUSIC.MENU)
    local host = self.host
    local win_tile_values = { 16, 2048 }
    local theme_values    = tileset.list_available()

    local lang_values = i18n.languages()
    local function current_lang_entry()
        for _, lang in ipairs(lang_values) do
            if lang.code == i18n.lang() then return lang end
        end
        return lang_values[1]
    end

    local items = {
        value_row(function() return i18n.t("options.win_tile") end, win_tile_values,
            function() return config.WIN_TILE end,
            function(v) config.WIN_TILE = v; settings.set("win_tile", v) end),
        value_row(function() return i18n.t("options.theme") end, theme_values,
            function() return config.TILESET end,
            function(v) config.TILESET = v; settings.set("theme", v) end,
            theme_label),
        value_row(function() return i18n.t("options.animations") end, BOOLEAN_VALUES,
            function() return config.ANIMATIONS_ENABLED end,
            function(v) config.ANIMATIONS_ENABLED = v; settings.set("animations_enabled", v) end,
            bool_label),
        value_row(function() return i18n.t("options.effects") end, BOOLEAN_VALUES,
            function() return config.EFFECTS_ENABLED end,
            function(v) config.EFFECTS_ENABLED = v; settings.set("effects_enabled", v) end,
            bool_label),
        value_row(function() return i18n.t("options.sound") end, BOOLEAN_VALUES,
            function() return config.SOUND.ENABLED end,
            function(v) config.SOUND.ENABLED = v; settings.set("sound_enabled", v) end,
            bool_label),
        value_row(function() return i18n.t("options.music") end, BOOLEAN_VALUES,
            function() return config.MUSIC.ENABLED end,
            function(v)
                config.MUSIC.ENABLED = v
                settings.set("music_enabled", v)
                if not v then music.stop() else music.play(config.MUSIC.MENU) end
            end,
            bool_label),
        value_row(function() return i18n.t("options.language") end, lang_values,
            current_lang_entry,
            function(v) i18n.set_lang(v.code); settings.set("language", v.code) end,
            function(v) return v.name end),
        { label = i18n.t("options.hint"), _label_fn = function() return i18n.t("options.hint") end, focusable = false },
        { label = i18n.t("menu.back"), _label_fn = function() return i18n.t("menu.back") end, on_activate = function() host:replace(host:spawn("main_menu"), PUSH_BCK, T_DUR) end, focus_before_activate = true },
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
    local items = self._mixin:items()
    refresh_items(items)
    return { title = i18n.t("screen.options"), bg_color = menu.BG_COLOR, item_style = "row", items = items }
end

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), self:cursor(), function(i) self._mixin:tap(i) end, x, y)
end

function Screen:draw()
    menu.draw_menu(self:spec(), self:cursor())
end

return M
