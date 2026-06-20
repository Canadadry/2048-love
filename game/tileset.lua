local config = require("config")

local M = {}

function M.parse_meta(t)
    return {
        tile_w = t.tile_width,
        tile_h = t.tile_height,
        frame_counts = t.frame_counts,
    }
end

function M.value_to_row(value)
    if value < 2 then return nil end
    local log = math.log(value) / math.log(2)
    local row = math.floor(log + 0.5)
    if 2 ^ row ~= value then return nil end
    return row
end

function M.load()
    local name = config.TILESET
    if not name or name == "" then return nil end
    local lua_path = "assets/" .. name .. ".lua"
    local png_path = "assets/" .. name .. ".png"
    local chunk = love.filesystem.load(lua_path)
    if not chunk then return nil end
    if not love.filesystem.getInfo(png_path) then return nil end
    local meta  = M.parse_meta(chunk())
    local image = love.graphics.newImage(png_path)
    local iw, ih = image:getDimensions()
    return { image = image, meta = meta, iw = iw, ih = ih }
end

return M
