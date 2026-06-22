local config       = require("config")
local tileset      = require("tileset")
local optionsmodel = require("optionsmodel")
local settings     = require("settings")
local menu         = require("menu")

local BACK_ROW = 5

local BOOLEAN_VALUES = { true, false }

local function index_of(values, value)
    for i, v in ipairs(values) do
        if v == value then return i end
    end
    return 1
end

local M = {}
local Screen = {}

function M.new(host)
    return setmetatable({ host = host }, { __index = Screen })
end

function Screen:enter()
    local win_tile_values = { 32, 2048 }
    local theme_values    = tileset.list_available()
    self._row_defs = {
        { label = "Win Tile",   values = win_tile_values, value_index = index_of(win_tile_values, config.WIN_TILE),
          config_key = "WIN_TILE", setting_key = "win_tile" },
        { label = "Theme",      values = theme_values,    value_index = index_of(theme_values, config.TILESET),
          config_key = "TILESET", setting_key = "theme" },
        { label = "Animations", values = BOOLEAN_VALUES,  value_index = index_of(BOOLEAN_VALUES, config.ANIMATIONS_ENABLED),
          config_key = "ANIMATIONS_ENABLED", setting_key = "animations_enabled" },
        { label = "Effects",    values = BOOLEAN_VALUES,  value_index = index_of(BOOLEAN_VALUES, config.EFFECTS_ENABLED),
          config_key = "EFFECTS_ENABLED", setting_key = "effects_enabled" },
        { label = "Back",       values = { true } },
    }
    self._model = optionsmodel.new(self._row_defs)
end

function Screen:focused_row()
    return self._model:focused_row()
end

local function persist_focused_row(self)
    local i   = self._model:focused_row()
    local row = self._row_defs[i]
    if not row.config_key then return end
    local value = self._model:row_value(i)
    config[row.config_key] = value
    settings.set(row.setting_key, value)
end

function Screen:draw()
    menu.draw_options(config.WIN_TILE, config.TILESET, config.ANIMATIONS_ENABLED, config.EFFECTS_ENABLED, self:focused_row())
end

function Screen:tap_row(i)
    if self._model:focused_row() ~= i then
        self._model:focus_row(i)
        return
    end
    if i == BACK_ROW then
        self.host:dismiss()
        return
    end
    self._model:right()
    persist_focused_row(self)
end

function Screen:keypressed(key)
    if key == "escape" then
        self.host:dismiss()
    elseif key == "up" then
        self._model:up()
    elseif key == "down" then
        self._model:down()
    elseif key == "left" or key == "right" then
        if key == "left" then self._model:left() else self._model:right() end
        persist_focused_row(self)
    elseif key == "return" then
        if self._model:focused_row() == BACK_ROW then
            self.host:dismiss()
        end
    end
end

return M
