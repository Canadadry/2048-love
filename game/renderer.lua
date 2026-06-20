local check   = require("check")
local config  = require("config")
local tileset = require("tileset")

local M = {}

local ts_data  = nil  -- { image, quads, tile_w, tile_h } set by M.load()
local font_cache = {}
local function get_font(size)
    if not font_cache[size] then
        font_cache[size] = love.graphics.newFont(size)
    end
    return font_cache[size]
end

function M.load()
    local ts = tileset.load()
    if not ts then return end
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

local function tile_color(value)
    return config.TILE_COLORS[value] or config.DEFAULT_TILE_COLOR
end

local function board_metrics()
    local w, h     = love.graphics.getDimensions()
    local n        = config.GRID_SIZE
    local board_px = math.floor(math.min(w, h) * 0.8)
    local tile_px  = math.floor(board_px / n)
    local pad      = math.max(4, math.floor(tile_px * 0.05))
    local board_x  = math.floor((w - board_px) / 2)
    local board_y  = math.floor((h - board_px) / 2) + 16
    return board_px, tile_px, pad, board_x, board_y
end

local function cell_to_px(r, c, tile_px, pad, board_x, board_y)
    return board_x + (c - 1) * tile_px + pad,
           board_y + (r - 1) * tile_px + pad
end

local function draw_tile(value, px, py, tile_px, pad, font)
    local sz = tile_px - pad * 2
    if ts_data and value ~= 0 and ts_data.quads[value] then
        local n     = ts_data.frame_counts[value]
        local frame = tileset.frame_at(n, config.TILESET_ANIM_FPS, ts_data.anim_time)
        local scale = sz / ts_data.tile_w
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(ts_data.image, ts_data.quads[value][frame], px, py, 0, scale, scale)
    else
        local colors = tile_color(value)
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
end

local function cell_key(r, c, n)
    return (r - 1) * n + c
end

function M.draw(cells, score, game_over, win, anim_tiles)
    check.tbl(cells,      "cells")
    check.num(score,      "score")
    check.bool(game_over, "game_over")
    check.bool(win,       "win")
    check.tbl(anim_tiles, "anim_tiles")

    local board_px, tile_px, pad, board_x, board_y = board_metrics()
    local n       = config.GRID_SIZE
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local font    = get_font(font_sz)

    love.graphics.setColor(0.73, 0.68, 0.63)
    love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)

    love.graphics.setFont(font)

    local animating = #anim_tiles > 0

    if animating then
        local dest = {}
        for _, t in ipairs(anim_tiles) do
            dest[cell_key(t.to_row, t.to_col, n)] = true
        end

        for r = 1, n do
            for c = 1, n do
                local px, py = cell_to_px(r, c, tile_px, pad, board_x, board_y)
                local val = dest[cell_key(r, c, n)] and 0 or cells[r][c]
                draw_tile(val, px, py, tile_px, pad, font)
            end
        end

        for _, t in ipairs(anim_tiles) do
            local progress = t:progress()
            local fx, fy   = cell_to_px(t.from_row, t.from_col, tile_px, pad, board_x, board_y)
            local tx, ty   = cell_to_px(t.to_row,   t.to_col,   tile_px, pad, board_x, board_y)
            local px = math.floor(fx + (tx - fx) * progress)
            local py = math.floor(fy + (ty - fy) * progress)
            draw_tile(t.value, px, py, tile_px, pad, font)
        end
    else
        for r = 1, n do
            for c = 1, n do
                local val    = cells[r][c]
                local px, py = cell_to_px(r, c, tile_px, pad, board_x, board_y)
                draw_tile(val, px, py, tile_px, pad, font)
            end
        end
    end

    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(get_font(math.max(12, font_sz - 4)))
    love.graphics.print("Score: " .. score, board_x, board_y - font_sz - 4)

    if win then
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)
        love.graphics.setColor(0.47, 0.43, 0.40)
        love.graphics.setFont(get_font(font_sz + 8))
        local msg = "You win!"
        love.graphics.print(msg,
            board_x + math.floor((board_px - get_font(font_sz + 8):getWidth(msg)) / 2),
            board_y + math.floor(board_px / 2) - font_sz)
    elseif game_over then
        love.graphics.setColor(0.24, 0.23, 0.20, 0.55)
        love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(get_font(font_sz + 8))
        local msg = "Game Over"
        love.graphics.print(msg,
            board_x + math.floor((board_px - get_font(font_sz + 8):getWidth(msg)) / 2),
            board_y + math.floor(board_px / 2) - font_sz)
        local btn = M.restart_button_bounds()
        love.graphics.setColor(0.93, 0.89, 0.85)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
        love.graphics.setColor(0.47, 0.43, 0.40)
        local btn_font = get_font(math.max(12, font_sz - 2))
        love.graphics.setFont(btn_font)
        local lbl = "New Game"
        love.graphics.print(lbl,
            btn.x + math.floor((btn.w - btn_font:getWidth(lbl)) / 2),
            btn.y + math.floor((btn.h - btn_font:getHeight()) / 2))
    end
end

function M.restart_button_bounds()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local btn_w   = math.floor(board_px * 0.4)
    local btn_h   = math.floor(font_sz * 2.2)
    local btn_x   = board_x + math.floor((board_px - btn_w) / 2)
    local btn_y   = board_y + math.floor(board_px / 2) + math.floor(font_sz * 0.5)
    return { x = btn_x, y = btn_y, w = btn_w, h = btn_h }
end

return M
