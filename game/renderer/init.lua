local check     = require("check")
local config    = require("config")
local menu      = require("menu")
local board     = require("renderer.board")
local tile_draw = require("renderer.tile_draw")
local hud       = require("renderer.hud")

local M = {}

local font_cache = {}
local function get_font(size)
    if not font_cache[size] then
        font_cache[size] = love.graphics.newFont(size)
    end
    return font_cache[size]
end

function M.set_tileset(name)
    tile_draw.set_tileset(name)
end

function M.update(dt)
    tile_draw.update(dt)
end

local function cell_key(r, c, n)
    return (r - 1) * n + c
end

function M.draw(cells, score, game_over, win, anim_tiles, cursor, paused, pause_cursor, win_particles)
    check.tbl(cells,      "cells")
    check.num(score,      "score")
    check.bool(game_over, "game_over")
    check.bool(win,       "win")
    check.tbl(anim_tiles, "anim_tiles")
    cursor       = cursor       or 0
    pause_cursor = pause_cursor or 0

    local board_px, tile_px, pad, board_x, board_y = board.metrics()
    local n       = config.GRID_SIZE
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local font    = get_font(font_sz)

    board.draw_background(board_x, board_y, board_px)

    love.graphics.setFont(font)

    local animating = #anim_tiles > 0

    if animating then
        local dest = {}
        for _, t in ipairs(anim_tiles) do
            dest[cell_key(t.to_row, t.to_col, n)] = true
        end

        for r = 1, n do
            for c = 1, n do
                local px, py = board.cell_to_px(r, c, tile_px, pad, board_x, board_y)
                local val = dest[cell_key(r, c, n)] and 0 or cells[r][c]
                tile_draw.draw(val, px, py, tile_px, pad, font)
            end
        end

        for _, t in ipairs(anim_tiles) do
            local progress = t:progress()
            local fx, fy   = board.cell_to_px(t.from_row, t.from_col, tile_px, pad, board_x, board_y)
            local tx, ty   = board.cell_to_px(t.to_row,   t.to_col,   tile_px, pad, board_x, board_y)
            local px = math.floor(fx + (tx - fx) * progress)
            local py = math.floor(fy + (ty - fy) * progress)
            tile_draw.draw(t.value, px, py, tile_px, pad, font, t.scale)
        end
    else
        for r = 1, n do
            for c = 1, n do
                local val    = cells[r][c]
                local px, py = board.cell_to_px(r, c, tile_px, pad, board_x, board_y)
                tile_draw.draw(val, px, py, tile_px, pad, font)
            end
        end
    end

    hud.draw(score, not paused and not win and not game_over)

    if paused then
        menu.draw_pause(pause_cursor)
    elseif win then
        menu.draw_win(cursor, win_particles)
    elseif game_over then
        menu.draw_game_over()
    end
end

return M
