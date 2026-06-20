local config = require("config")

local M = {}

local font_cache = {}
local function get_font(size)
    if not font_cache[size] then
        font_cache[size] = love.graphics.newFont(size)
    end
    return font_cache[size]
end

local function tile_color(value)
    return config.TILE_COLORS[value] or config.DEFAULT_TILE_COLOR
end

function M.draw(cells, score, game_over, win)
    local w, h    = love.graphics.getDimensions()
    local n       = config.GRID_SIZE
    local board_px = math.floor(math.min(w, h) * 0.8)
    local tile_px  = math.floor(board_px / n)
    local pad      = math.max(4, math.floor(tile_px * 0.05))
    local board_x  = math.floor((w - board_px) / 2)
    local board_y  = math.floor((h - board_px) / 2) + 16
    local font_sz  = math.max(12, math.floor(tile_px * 0.30))
    local font     = get_font(font_sz)

    -- board background
    love.graphics.setColor(0.73, 0.68, 0.63)
    love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)

    love.graphics.setFont(font)

    for r = 1, n do
        for c = 1, n do
            local val    = cells[r][c]
            local colors = tile_color(val)
            local tx = board_x + (c - 1) * tile_px + pad
            local ty = board_y + (r - 1) * tile_px + pad
            local ts = tile_px - pad * 2

            love.graphics.setColor(colors.bg)
            love.graphics.rectangle("fill", tx, ty, ts, ts, 6, 6)

            if val ~= 0 then
                local text = tostring(val)
                local fw   = font:getWidth(text)
                local fh   = font:getHeight()
                love.graphics.setColor(colors.fg)
                love.graphics.print(text,
                    math.floor(tx + (ts - fw) / 2),
                    math.floor(ty + (ts - fh) / 2))
            end
        end
    end

    -- score line above board
    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(get_font(math.max(12, font_sz - 4)))
    love.graphics.print("Score: " .. score, board_x, board_y - font_sz - 4)

    -- frozen overlay
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
    end
end

return M
