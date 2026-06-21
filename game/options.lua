local config  = require("config")
local tileset = require("tileset")

local M = {}

function M.new(ctx, Base)
    local OptionsState = setmetatable({}, Base)
    OptionsState.__index = OptionsState

    function OptionsState:in_options()     return true end
    function OptionsState:tileset_names()  return self._names end
    function OptionsState:tileset_cursor() return self._cursor end

    function OptionsState:enter()
        self._names = tileset.list_available()
        self._cursor = 1
        for i, name in ipairs(self._names) do
            if name == config.TILESET then self._cursor = i; break end
        end
    end

    function OptionsState:keypressed(key)
        if key == "escape" then
            ctx.switch("menu")
        elseif key == "left" or key == "right" then
            config.WIN_TILE = (config.WIN_TILE == 2048) and 32 or 2048
        elseif key == "down" then
            self._cursor = math.min(#self._names, self._cursor + 1)
        elseif key == "up" then
            self._cursor = math.max(1, self._cursor - 1)
        elseif key == "return" then
            config.TILESET = self._names[self._cursor]
        end
    end

    return setmetatable({ _ctx = ctx }, OptionsState)
end

return M
