local config = require("config")

local M = {}

local font_cache = {}
local function get_font(size)
    if not font_cache[size] then
        font_cache[size] = love.graphics.newFont(size)
    end
    return font_cache[size]
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

function M.win_button_bounds()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local btn_w   = math.floor(board_px * 0.5)
    local btn_h   = math.floor(font_sz * 2.2)
    local btn_x   = board_x + math.floor((board_px - btn_w) / 2)
    local gap     = math.floor(font_sz * 0.6)
    local top_y   = board_y + math.floor(board_px * 0.52)
    return {
        continue_btn = { x = btn_x, y = top_y,               w = btn_w, h = btn_h, label = "Continue" },
        restart_btn  = { x = btn_x, y = top_y + btn_h + gap, w = btn_w, h = btn_h, label = "Restart"  },
    }
end

function M.game_over_button_bounds()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local btn_w   = math.floor(board_px * 0.4)
    local btn_h   = math.floor(font_sz * 2.2)
    local btn_x   = board_x + math.floor((board_px - btn_w) / 2)
    local btn_y   = board_y + math.floor(board_px / 2) + math.floor(font_sz * 0.5)
    return { x = btn_x, y = btn_y, w = btn_w, h = btn_h }
end

function M.draw_win(cursor)
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz    = math.max(12, math.floor(tile_px * 0.30))
    local title_font = get_font(font_sz + 8)
    local btn_font   = get_font(math.max(12, font_sz - 2))
    local bounds     = M.win_button_bounds()

    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)
    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(title_font)
    local msg = "You Win!"
    love.graphics.print(msg,
        board_x + math.floor((board_px - title_font:getWidth(msg)) / 2),
        board_y + math.floor(board_px * 0.30))
    love.graphics.setFont(btn_font)
    for i, b in ipairs({ bounds.continue_btn, bounds.restart_btn }) do
        local selected = (cursor == i - 1)
        love.graphics.setColor(selected and { 0.96, 0.49, 0.37 } or { 0.93, 0.89, 0.85 })
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
        love.graphics.setColor(selected and { 1, 1, 1 } or { 0.47, 0.43, 0.40 })
        local lbl = b.label
        love.graphics.print(lbl,
            b.x + math.floor((b.w - btn_font:getWidth(lbl)) / 2),
            b.y + math.floor((b.h - btn_font:getHeight()) / 2))
    end
end

function M.draw_game_over()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz  = math.max(12, math.floor(tile_px * 0.30))
    local btn      = M.game_over_button_bounds()
    local btn_font = get_font(math.max(12, font_sz - 2))
    local title_font = get_font(font_sz + 8)

    love.graphics.setColor(0.24, 0.23, 0.20, 0.55)
    love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(title_font)
    local msg = "Game Over"
    love.graphics.print(msg,
        board_x + math.floor((board_px - title_font:getWidth(msg)) / 2),
        board_y + math.floor(board_px / 2) - font_sz)
    love.graphics.setColor(0.93, 0.89, 0.85)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(btn_font)
    local lbl = "New Game"
    love.graphics.print(lbl,
        btn.x + math.floor((btn.w - btn_font:getWidth(lbl)) / 2),
        btn.y + math.floor((btn.h - btn_font:getHeight()) / 2))
end

return M
