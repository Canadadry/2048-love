local config  = require("config")
local builder = require("lib.ui.layout.builder")
local ui      = require("lib.ui.layout.ui")
local painter = require("lib.ui.painter.painter")
local board   = require("renderer.board")

local M = {}

local font_cache = {}
local function get_font(size)
    if not font_cache[size] then
        font_cache[size] = love.graphics.newFont(size)
    end
    return font_cache[size]
end

local board_metrics = board.metrics

local MENU_BG_COLOR          = { 250, 247, 240, 255 }
local MENU_ACCENT_COLOR      = { 245, 125, 94, 255 }
local MENU_NORMAL_BTN_COLOR  = { 237, 227, 217, 255 }
local MENU_NORMAL_TEXT_COLOR = { 120, 110, 102, 255 }
local MENU_WHITE_COLOR       = { 255, 255, 255, 255 }

local function menu_sizes()
    local board_px, tile_px = board_metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local btn_w   = math.floor(board_px * 0.5)
    local btn_h   = math.floor(font_sz * 2.2)
    local gap     = math.floor(font_sz * 0.6)
    return font_sz, btn_w, btn_h, gap
end

local function menu_button(label, btn_w, btn_h, btn_font, selected, onTap)
    return builder.Node(
        string.format("w-%d h-%d center", btn_w, btn_h),
        painter.Group {
            painters = {
                painter.Rectangle {
                    color   = selected and MENU_ACCENT_COLOR or MENU_NORMAL_BTN_COLOR,
                    rounded = 6,
                    segment = 8,
                },
                painter.Interactive { onTap = onTap },
            }
        },
        {
            builder.Leaf("grow-x h-fit", painter.Text {
                text  = label,
                align = "center",
                font  = btn_font,
                color = selected and MENU_WHITE_COLOR or MENU_NORMAL_TEXT_COLOR,
            }),
        }
    )
end

local function build_main_menu_tree(cursor, callbacks)
    callbacks = callbacks or {}
    local w, h = love.graphics.getDimensions()
    local font_sz, btn_w, btn_h, gap = menu_sizes()
    local title_font = get_font(font_sz + 16)
    local btn_font   = get_font(math.max(12, font_sz - 2))

    local tree = painter.Tree()
    builder.Build(tree, builder.Node(
        string.format("w-%d h-%d center", w, h),
        painter.Rectangle { color = MENU_BG_COLOR },
        {
            builder.Node(string.format("col gap-%d center", gap), nil, {
                builder.Leaf("grow-x h-fit", painter.Text {
                    text  = "2048",
                    align = "center",
                    font  = title_font,
                    color = MENU_NORMAL_TEXT_COLOR,
                }),
                menu_button("New Game", btn_w, btn_h, btn_font, cursor == 0, callbacks.on_new_game),
                menu_button("Options",  btn_w, btn_h, btn_font, cursor == 1, callbacks.on_options),
                menu_button("Quit",     btn_w, btn_h, btn_font, cursor == 2, callbacks.on_quit),
            }),
        }
    ))
    return tree
end

function M.main_menu_tree(cursor, callbacks)
    local tree = build_main_menu_tree(cursor, callbacks)
    ui.DrawTree(tree)
    return tree
end

function M.draw_main_menu(cursor)
    local tree = M.main_menu_tree(cursor, nil)
    painter.DrawTree(tree)
end

function M.main_menu_hit_test(cursor, callbacks, x, y)
    local tree = M.main_menu_tree(cursor, callbacks)
    ui.Tap(tree, x, y)
end

local function theme_label(name)
    return name == "" and "None (classic)" or name
end

local function bool_label(enabled)
    return enabled and "ON" or "OFF"
end

local function options_row(label, value, focused, body_font, on_tap)
    local text = value == nil and label or (label .. ":  <  " .. value .. "  >")
    return builder.Node("grow-x h-fit py-4", painter.Interactive {
        onTap = on_tap,
    }, {
        builder.Leaf("grow-x h-fit", painter.Text {
            text  = text,
            align = "center",
            font  = body_font,
            color = focused and MENU_ACCENT_COLOR or MENU_NORMAL_TEXT_COLOR,
        }),
    })
end

local function build_options_tree(win_tile, theme, animations_enabled, effects_enabled, focused_row, callbacks)
    callbacks = callbacks or {}
    local w, h = love.graphics.getDimensions()
    local font_sz    = menu_sizes()
    local title_font = get_font(font_sz + 16)
    local body_font  = get_font(math.max(12, font_sz - 2))
    local hint_font  = get_font(math.max(10, font_sz - 6))
    local row_gap    = math.floor(font_sz * 0.3)

    local function on_row_tap(i)
        return function()
            if callbacks.on_row_tap then
                callbacks.on_row_tap(i)
            end
        end
    end

    local function on_back()
        if callbacks.on_back then
            callbacks.on_back()
        end
    end

    local tree = painter.Tree()
    builder.Build(tree, builder.Node(
        string.format("w-%d h-%d center", w, h),
        painter.Rectangle { color = MENU_BG_COLOR },
        {
            builder.Node(string.format("col gap-%d center", row_gap), nil, {
                builder.Leaf("grow-x h-fit", painter.Text {
                    text  = "Options",
                    align = "center",
                    font  = title_font,
                    color = MENU_NORMAL_TEXT_COLOR,
                }),
                options_row("Win Tile",   win_tile,                       focused_row == 1, body_font, on_row_tap(1)),
                options_row("Theme",      theme_label(theme),             focused_row == 2, body_font, on_row_tap(2)),
                options_row("Animations", bool_label(animations_enabled), focused_row == 3, body_font, on_row_tap(3)),
                options_row("Effects",    bool_label(effects_enabled),    focused_row == 4, body_font, on_row_tap(4)),
                builder.Leaf("grow-x h-fit", painter.Text {
                    text  = "Up/Down to focus a row, Left/Right to change its value, or tap a row",
                    align = "center",
                    font  = hint_font,
                    color = MENU_NORMAL_TEXT_COLOR,
                }),
                options_row("Back", nil, focused_row == 5, body_font, on_back),
            }),
        }
    ))
    return tree
end

function M.options_tree(win_tile, theme, animations_enabled, effects_enabled, focused_row, callbacks)
    local tree = build_options_tree(win_tile, theme, animations_enabled, effects_enabled, focused_row, callbacks)
    ui.DrawTree(tree)
    return tree
end

function M.draw_options(win_tile, theme, animations_enabled, effects_enabled, focused_row)
    local tree = M.options_tree(win_tile, theme, animations_enabled, effects_enabled, focused_row, nil)
    painter.DrawTree(tree)
end

function M.options_hit_test(win_tile, theme, animations_enabled, effects_enabled, focused_row, callbacks, x, y)
    local tree = M.options_tree(win_tile, theme, animations_enabled, effects_enabled, focused_row, callbacks)
    ui.Tap(tree, x, y)
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

local WIN_DIM_COLOR = { 255, 255, 255, 140 }

local function build_win_tree(cursor, callbacks)
    callbacks = callbacks or {}
    local w, h = love.graphics.getDimensions()
    local font_sz, btn_w, btn_h, gap = menu_sizes()
    local title_font = get_font(font_sz + 8)
    local btn_font   = get_font(math.max(12, font_sz - 2))

    local tree = painter.Tree()
    builder.Build(tree, builder.Node(
        string.format("w-%d h-%d center", w, h),
        painter.Rectangle { color = WIN_DIM_COLOR },
        {
            builder.Node(string.format("col gap-%d center", gap), nil, {
                builder.Leaf("grow-x h-fit", painter.Text {
                    text  = "You Win!",
                    align = "center",
                    font  = title_font,
                    color = MENU_NORMAL_TEXT_COLOR,
                }),
                menu_button("Continue", btn_w, btn_h, btn_font, cursor == 0, callbacks.on_continue),
                menu_button("Restart",  btn_w, btn_h, btn_font, cursor == 1, callbacks.on_restart),
            }),
        }
    ))
    return tree
end

function M.win_tree(cursor, callbacks)
    local tree = build_win_tree(cursor, callbacks)
    ui.DrawTree(tree)
    return tree
end

function M.win_hit_test(cursor, callbacks, x, y)
    local tree = M.win_tree(cursor, callbacks)
    ui.Tap(tree, x, y)
end

local GAME_OVER_DIM_COLOR = { 61, 59, 51, 140 }

local function build_game_over_tree(callbacks)
    callbacks = callbacks or {}
    local w, h = love.graphics.getDimensions()
    local font_sz, _, btn_h, gap = menu_sizes()
    local board_px = board_metrics()
    local btn_w = math.floor(board_px * 0.4)
    local title_font = get_font(font_sz + 8)
    local btn_font   = get_font(math.max(12, font_sz - 2))

    local tree = painter.Tree()
    builder.Build(tree, builder.Node(
        string.format("w-%d h-%d center", w, h),
        painter.Rectangle { color = GAME_OVER_DIM_COLOR },
        {
            builder.Node(string.format("col gap-%d center", gap), nil, {
                builder.Leaf("grow-x h-fit", painter.Text {
                    text  = "Game Over",
                    align = "center",
                    font  = title_font,
                    color = MENU_WHITE_COLOR,
                }),
                menu_button("New Game", btn_w, btn_h, btn_font, false, callbacks.on_restart),
            }),
        }
    ))
    return tree
end

function M.game_over_tree(callbacks)
    local tree = build_game_over_tree(callbacks)
    ui.DrawTree(tree)
    return tree
end

function M.game_over_hit_test(callbacks, x, y)
    local tree = M.game_over_tree(callbacks)
    ui.Tap(tree, x, y)
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
    local tree = M.win_tree(cursor, nil)
    painter.DrawTree(tree)
    draw_win_particles(particles)
end

function M.draw_game_over()
    local tree = M.game_over_tree(nil)
    painter.DrawTree(tree)
end

return M
