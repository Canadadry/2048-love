local config       = require("config")
local tileset      = require("tileset")
local optionsmodel = require("optionsmodel")
local settings     = require("settings")

local WIN_TILE_ROW = 1
local THEME_ROW     = 2

local function index_of(values, value)
    for i, v in ipairs(values) do
        if v == value then return i end
    end
    return 1
end

local M = {}

function M.new(ctx, Base)
    local OptionsState = setmetatable({}, Base)
    OptionsState.__index = OptionsState

    function OptionsState:in_options()  return true end
    function OptionsState:focused_row() return self._model:focused_row() end

    function OptionsState:enter()
        local win_tile_values = { 32, 2048 }
        local theme_values    = tileset.list_available()
        self._model = optionsmodel.new({
            { label = "Win Tile", values = win_tile_values, value_index = index_of(win_tile_values, config.WIN_TILE) },
            { label = "Theme",    values = theme_values,    value_index = index_of(theme_values, config.TILESET) },
        })
    end

    function OptionsState:keypressed(key)
        if key == "escape" then
            ctx.switch("menu")
        elseif key == "up" then
            self._model:up()
        elseif key == "down" then
            self._model:down()
        elseif key == "left" or key == "right" then
            if key == "left" then self._model:left() else self._model:right() end
            local row = self._model:focused_row()
            if row == WIN_TILE_ROW then
                config.WIN_TILE = self._model:row_value(WIN_TILE_ROW)
                settings.set("win_tile", config.WIN_TILE)
            else
                config.TILESET = self._model:row_value(THEME_ROW)
                settings.set("theme", config.TILESET)
            end
        end
    end

    return setmetatable({ _ctx = ctx }, OptionsState)
end

return M
