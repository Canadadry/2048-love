local check = require("lib.check")

local M = {}

function M.parse_meta(t)
    check.tbl(t, "tileset meta")
    assert(type(t.tile_width)  == "number" and t.tile_width  > 0, "tile_width must be a positive number")
    assert(type(t.tile_height) == "number" and t.tile_height > 0, "tile_height must be a positive number")
    return {
        tile_w = t.tile_width,
        tile_h = t.tile_height,
        frame_counts = t.frame_counts,
    }
end

function M.value_to_row(value)
    check.num(value, "value")
    if value < 2 then return nil end
    local log = math.log(value) / math.log(2)
    local row = math.floor(log + 0.5)
    if 2 ^ row ~= value then return nil end
    return row
end

function M.list_names(filenames)
    check.tbl(filenames, "filenames")
    local names = {}
    for _, f in ipairs(filenames) do
        local name = f:match("^(.+)%.png$")
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    table.insert(names, 1, "")
    return names
end

function M.list_available()
    return M.list_names(love.filesystem.getDirectoryItems("assets"))
end

function M.load(name)
    if not name or name == "" then return nil end
    local lua_path = "assets/" .. name .. ".lua"
    local png_path = "assets/" .. name .. ".png"
    local chunk = love.filesystem.load(lua_path)
    if not chunk then return nil end
    if not love.filesystem.getInfo(png_path) then return nil end
    local meta  = M.parse_meta(chunk())
    local image = love.graphics.newImage(png_path)
    local iw, ih = image:getDimensions()
    local max_tex = love.graphics.getSystemLimits().texturesize
    print(string.format("tileset.load(%q): image %dx%d, GPU max texture size %d", name, iw, ih, max_tex))
    assert(iw <= max_tex and ih <= max_tex, string.format(
        "tileset '%s' image is %dx%d but this GPU's max texture size is %d — rebuild it with a smaller --tile-width/--tile-height or fewer frames",
        name, iw, ih, max_tex))
    return { image = image, meta = meta, iw = iw, ih = ih }
end

function M.frame_at(frame_count, fps, time)
    check.num(frame_count, "frame_count")
    check.num(fps,         "fps")
    check.num(time,        "time")
    assert(frame_count >= 1, "frame_count must be >= 1, got " .. tostring(frame_count))
    assert(fps > 0,          "fps must be positive, got " .. tostring(fps))
    assert(time >= 0,        "time must be non-negative, got " .. tostring(time))
    return math.floor(time * fps) % frame_count
end

return M
