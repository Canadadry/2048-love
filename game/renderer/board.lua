local config = require("config")

local M = {}

function M.metrics()
    local w, h     = love.graphics.getDimensions()
    local n        = config.GRID_SIZE
    local board_px = math.floor(math.min(w, h) * 0.8)
    local tile_px  = math.floor(board_px / n)
    local pad      = math.max(4, math.floor(tile_px * 0.05))
    local board_x  = math.floor((w - board_px) / 2)
    local board_y  = math.floor((h - board_px) / 2) + 16
    return board_px, tile_px, pad, board_x, board_y
end

function M.cell_to_px(r, c, tile_px, pad, board_x, board_y)
    return board_x + (c - 1) * tile_px + pad,
           board_y + (r - 1) * tile_px + pad
end

function M.draw_background(board_x, board_y, board_px)
    love.graphics.setColor(0.73, 0.68, 0.63)
    love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)
end

return M
