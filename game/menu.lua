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

function M.main_menu_button_bounds()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local btn_w   = math.floor(board_px * 0.5)
    local btn_h   = math.floor(font_sz * 2.2)
    local btn_x   = board_x + math.floor((board_px - btn_w) / 2)
    local gap     = math.floor(font_sz * 0.6)
    local top_y   = board_y + math.floor(board_px * 0.35)
    return {
        { x = btn_x, y = top_y,                     w = btn_w, h = btn_h, label = "New Game" },
        { x = btn_x, y = top_y + (btn_h + gap),     w = btn_w, h = btn_h, label = "Options"  },
        { x = btn_x, y = top_y + (btn_h + gap) * 2, w = btn_w, h = btn_h, label = "Quit"      },
    }
end

function M.draw_main_menu(cursor)
    local w, h = love.graphics.getDimensions()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz    = math.max(12, math.floor(tile_px * 0.30))
    local title_font = get_font(font_sz + 16)
    local btn_font   = get_font(math.max(12, font_sz - 2))
    local btns       = M.main_menu_button_bounds()

    love.graphics.setColor(0.98, 0.97, 0.94)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(title_font)
    local title = "2048"
    love.graphics.print(title,
        board_x + math.floor((board_px - title_font:getWidth(title)) / 2),
        board_y + math.floor(board_px * 0.20))

    love.graphics.setFont(btn_font)
    for i, b in ipairs(btns) do
        local selected = (cursor == i - 1)
        love.graphics.setColor(selected and { 0.96, 0.49, 0.37 } or { 0.93, 0.89, 0.85 })
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
        love.graphics.setColor(selected and { 1, 1, 1 } or { 0.47, 0.43, 0.40 })
        love.graphics.print(b.label,
            b.x + math.floor((b.w - btn_font:getWidth(b.label)) / 2),
            b.y + math.floor((b.h - btn_font:getHeight()) / 2))
    end
end

local function theme_label(name)
    return name == "" and "None (classic)" or name
end

local ACCENT_COLOR = { 0.96, 0.49, 0.37 }
local NORMAL_COLOR  = { 0.47, 0.43, 0.40 }

local function bool_label(enabled)
    return enabled and "ON" or "OFF"
end

function M.draw_options(win_tile, theme, animations_enabled, effects_enabled, focused_row)
    local w, h = love.graphics.getDimensions()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz     = math.max(12, math.floor(tile_px * 0.30))
    local title_font  = get_font(font_sz + 16)
    local body_font   = get_font(math.max(12, font_sz - 2))
    local hint_font   = get_font(math.max(10, font_sz - 6))

    love.graphics.setColor(0.98, 0.97, 0.94)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(NORMAL_COLOR)
    love.graphics.setFont(title_font)
    local title = "Options"
    love.graphics.print(title,
        board_x + math.floor((board_px - title_font:getWidth(title)) / 2),
        board_y + math.floor(board_px * 0.20))

    love.graphics.setFont(body_font)
    local line_h = body_font:getHeight() + 4
    local row_y  = board_y + math.floor(board_px * 0.45)

    local win_tile_msg = "Win Tile:  <  " .. win_tile .. "  >"
    love.graphics.setColor(focused_row == 1 and ACCENT_COLOR or NORMAL_COLOR)
    love.graphics.print(win_tile_msg,
        board_x + math.floor((board_px - body_font:getWidth(win_tile_msg)) / 2),
        row_y)

    local theme_msg = "Theme:  <  " .. theme_label(theme) .. "  >"
    love.graphics.setColor(focused_row == 2 and ACCENT_COLOR or NORMAL_COLOR)
    love.graphics.print(theme_msg,
        board_x + math.floor((board_px - body_font:getWidth(theme_msg)) / 2),
        row_y + line_h)

    local animations_msg = "Animations:  <  " .. bool_label(animations_enabled) .. "  >"
    love.graphics.setColor(focused_row == 3 and ACCENT_COLOR or NORMAL_COLOR)
    love.graphics.print(animations_msg,
        board_x + math.floor((board_px - body_font:getWidth(animations_msg)) / 2),
        row_y + line_h * 2)

    local effects_msg = "Effects:  <  " .. bool_label(effects_enabled) .. "  >"
    love.graphics.setColor(focused_row == 4 and ACCENT_COLOR or NORMAL_COLOR)
    love.graphics.print(effects_msg,
        board_x + math.floor((board_px - body_font:getWidth(effects_msg)) / 2),
        row_y + line_h * 3)

    love.graphics.setColor(NORMAL_COLOR)
    love.graphics.setFont(hint_font)
    local hint = "Up/Down to focus a row, Left/Right to change its value"
    love.graphics.print(hint,
        board_x + math.floor((board_px - hint_font:getWidth(hint)) / 2),
        row_y + line_h * 4 + 6)
end

function M.pause_icon_bounds()
    local _, tile_px = board_metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local sz      = math.max(44, font_sz + 8)
    return { x = 8, y = 8, w = sz, h = sz }
end

function M.draw_pause_icon()
    local b       = M.pause_icon_bounds()
    local bar_w   = math.max(3, math.floor(b.w * 0.15))
    local bar_h   = math.floor(b.h * 0.50)
    local gap     = math.floor(b.w * 0.18)
    local total_w = bar_w * 2 + gap
    local bar_x   = b.x + math.floor((b.w - total_w) / 2)
    local bar_y   = b.y + math.floor((b.h - bar_h) / 2)

    love.graphics.setColor(0.47, 0.43, 0.40, 0.85)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.90)
    love.graphics.rectangle("fill", bar_x,               bar_y, bar_w, bar_h)
    love.graphics.rectangle("fill", bar_x + bar_w + gap, bar_y, bar_w, bar_h)
end

function M.pause_button_bounds()
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local btn_w   = math.floor(board_px * 0.5)
    local btn_h   = math.floor(font_sz * 2.2)
    local btn_x   = board_x + math.floor((board_px - btn_w) / 2)
    local gap     = math.floor(font_sz * 0.6)
    local top_y   = board_y + math.floor(board_px * 0.27)
    return {
        { x = btn_x, y = top_y,                       w = btn_w, h = btn_h, label = "Resume"    },
        { x = btn_x, y = top_y + (btn_h + gap),       w = btn_w, h = btn_h, label = "New Game"  },
        { x = btn_x, y = top_y + (btn_h + gap) * 2,   w = btn_w, h = btn_h, label = "Main Menu" },
        { x = btn_x, y = top_y + (btn_h + gap) * 3,   w = btn_w, h = btn_h, label = "Quit"      },
    }
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

function M.draw_pause(pause_cursor)
    local board_px, tile_px, _, board_x, board_y = board_metrics()
    local font_sz    = math.max(12, math.floor(tile_px * 0.30))
    local title_font = get_font(font_sz + 8)
    local btn_font   = get_font(math.max(12, font_sz - 2))
    local btns       = M.pause_button_bounds()

    love.graphics.setColor(0.24, 0.23, 0.20, 0.60)
    love.graphics.rectangle("fill", board_x, board_y, board_px, board_px)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(title_font)
    local msg = "Paused"
    love.graphics.print(msg,
        board_x + math.floor((board_px - title_font:getWidth(msg)) / 2),
        board_y + math.floor(board_px * 0.18))
    love.graphics.setFont(btn_font)
    for i, b in ipairs(btns) do
        local selected = (pause_cursor == i - 1)
        love.graphics.setColor(selected and { 0.96, 0.49, 0.37 } or { 0.93, 0.89, 0.85 })
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
        love.graphics.setColor(selected and { 1, 1, 1 } or { 0.47, 0.43, 0.40 })
        love.graphics.print(b.label,
            b.x + math.floor((b.w - btn_font:getWidth(b.label)) / 2),
            b.y + math.floor((b.h - btn_font:getHeight()) / 2))
    end
end

local function draw_win_particles(particles)
    if not particles or #particles == 0 then return end
    local size  = config.PARTICLE_SIZE
    local w, h  = love.graphics.getDimensions()
    for _, p in ipairs(particles) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x * w, p.y * h, size, size)
    end
end

function M.draw_win(cursor, particles)
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
    draw_win_particles(particles)
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
