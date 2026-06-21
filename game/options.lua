local config = require("config")

local M = {}

function M.new(ctx, Base)
    local OptionsState = setmetatable({}, Base)
    OptionsState.__index = OptionsState

    function OptionsState:in_options() return true end

    function OptionsState:keypressed(key)
        if key == "escape" then
            ctx.switch("menu")
        elseif key == "left" or key == "right" then
            config.WIN_TILE = (config.WIN_TILE == 2048) and 32 or 2048
        end
    end

    return setmetatable({ _ctx = ctx }, OptionsState)
end

return M
