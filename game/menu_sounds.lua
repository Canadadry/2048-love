local sound  = require("lib.sound")
local config = require("config")

local function play(path)
    if config.SOUND.ENABLED then sound.play(path) end
end

return {
    on_select = function() play(config.SOUND.SELECT) end,
    on_change = function() play(config.SOUND.CHANGE) end,
}
