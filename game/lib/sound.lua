local M      = {}
local _cache = {}

local function get(path)
    if not _cache[path] then
        _cache[path] = love.audio.newSource(path, "static")
    end
    return _cache[path]
end

function M.play(path)
    if not path or path == "" then return end
    if not love or not love.audio then return end
    local src = get(path)
    src:stop()
    src:play()
end

return M
