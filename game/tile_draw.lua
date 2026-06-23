local config  = require("config")
local tileset = require("tileset")

local M = {}

local ts_data = nil  -- { image, quads, frame_counts, tile_w, tile_h, anim_time } set by M.set_tileset()

M.NOT_LOADED = {}  -- sentinel: distinct from any legal tileset name, including ""
local loaded_name = M.NOT_LOADED

function M.needs_reload(requested_name, loaded)
    return requested_name ~= loaded
end

function M.set_tileset(name)
    if not M.needs_reload(name, loaded_name) then return end
    loaded_name = name
    local ts = tileset.load(name)
    if not ts then ts_data = nil; return end
    local quads        = {}
    local frame_counts = {}
    local values       = { 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048 }
    for i, v in ipairs(values) do
        local row = tileset.value_to_row(v)
        if row then
            local n = (ts.meta.frame_counts and ts.meta.frame_counts[i]) or 1
            frame_counts[v] = n
            quads[v] = {}
            for f = 0, n - 1 do
                quads[v][f] = love.graphics.newQuad(
                    f * ts.meta.tile_w, (row - 1) * ts.meta.tile_h,
                    ts.meta.tile_w, ts.meta.tile_h,
                    ts.iw, ts.ih
                )
            end
        end
    end
    ts_data = {
        image        = ts.image,
        quads        = quads,
        frame_counts = frame_counts,
        tile_w       = ts.meta.tile_w,
        tile_h       = ts.meta.tile_h,
        anim_time    = 0,
    }
end

function M.update(dt)
    if ts_data then
        ts_data.anim_time = ts_data.anim_time + dt
    end
end

function M.tile_color(value)
    return config.TILE_COLORS[value] or config.DEFAULT_TILE_COLOR
end

function M.draw(value, px, py, tile_px, pad, font, pop_scale)
    pop_scale = pop_scale or 1
    local sz = tile_px - pad * 2

    if pop_scale ~= 1 then
        love.graphics.push()
        local cx, cy = px + sz / 2, py + sz / 2
        love.graphics.translate(cx, cy)
        love.graphics.scale(pop_scale, pop_scale)
        love.graphics.translate(-cx, -cy)
    end

    if ts_data and value ~= 0 and ts_data.quads[value] then
        local n     = ts_data.frame_counts[value]
        local frame = tileset.frame_at(n, config.TILESET_ANIM_FPS, ts_data.anim_time)
        local scale = sz / ts_data.tile_w
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(ts_data.image, ts_data.quads[value][frame], px, py, 0, scale, scale)
    else
        local colors = M.tile_color(value)
        love.graphics.setColor(colors.bg)
        love.graphics.rectangle("fill", px, py, sz, sz, 6, 6)
        if value ~= 0 then
            local text = tostring(value)
            local fw   = font:getWidth(text)
            local fh   = font:getHeight()
            love.graphics.setColor(colors.fg)
            love.graphics.print(text,
                math.floor(px + (sz - fw) / 2),
                math.floor(py + (sz - fh) / 2))
        end
    end

    if pop_scale ~= 1 then
        love.graphics.pop()
    end
end

return M
