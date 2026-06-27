local config = require("config")

local M = {}
local _source       = nil
local _current_path = nil

function M.play(path)
    if not path or path == "" then return end
    if not config.MUSIC.ENABLED then return end
    if not love or not love.audio then return end
    if _current_path == path then return end
    if _source then _source:stop() end
    _source = love.audio.newSource(path, "stream")
    _source:setLooping(true)
    _source:play()
    _current_path = path
end

function M.stop()
    if _source then _source:stop() end
    _source       = nil
    _current_path = nil
end

function M._reset()
    _source       = nil
    _current_path = nil
end

return M
