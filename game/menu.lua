local config     = require("config")
local builder    = require("lib.ui.layout.builder")
local ui         = require("lib.ui.layout.ui")
local painter    = require("lib.ui.painter.painter")
local board      = require("board")
local font_cache = require("lib.font_cache")

local M = {}

local get_font = font_cache.get_font

local board_metrics = board.metrics

local MENU_BG_COLOR          = { 250, 247, 240, 255 }
local MENU_ACCENT_COLOR      = { 245, 125, 94, 255 }
local MENU_NORMAL_BTN_COLOR  = { 237, 227, 217, 255 }
local MENU_NORMAL_TEXT_COLOR = { 120, 110, 102, 255 }
local MENU_WHITE_COLOR       = { 255, 255, 255, 255 }

M.BG_COLOR    = MENU_BG_COLOR
M.WHITE_COLOR = MENU_WHITE_COLOR

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

local function build_menu_tree(spec, cursor, on_tap)
    local w, h = love.graphics.getDimensions()
    local font_sz, default_btn_w, btn_h, gap = menu_sizes()
    local board_px   = board_metrics()
    local btn_w      = spec.btn_w_ratio and math.floor(board_px * spec.btn_w_ratio) or default_btn_w
    local title_font = get_font(font_sz + (spec.title_font_offset or 16))
    local btn_font   = get_font(math.max(12, font_sz - 2))
    local hint_font  = get_font(math.max(10, font_sz - 6))
    local text_color = spec.text_color or MENU_NORMAL_TEXT_COLOR
    local list_gap   = spec.item_style == "row" and math.floor(font_sz * 0.3) or gap

    local function tap_item(i)
        return function() if on_tap then on_tap(i) end end
    end

    local children = {}
    if spec.title then
        children[#children + 1] = builder.Leaf("grow-x h-fit", painter.Text {
            text  = spec.title,
            align = "center",
            font  = title_font,
            color = text_color,
        })
    end
    for i, item in ipairs(spec.items) do
        if item.focusable == false then
            children[#children + 1] = builder.Leaf("grow-x h-fit", painter.Text {
                text  = item.label,
                align = "center",
                font  = hint_font,
                color = text_color,
            })
        elseif spec.item_style == "row" then
            children[#children + 1] = options_row(item.label, item.value, cursor == i - 1, btn_font, tap_item(i))
        else
            children[#children + 1] = menu_button(item.label, btn_w, btn_h, btn_font, cursor == i - 1, tap_item(i))
        end
    end

    local tree = painter.Tree()
    builder.Build(tree, builder.Node(
        string.format("w-%d h-%d center", w, h),
        painter.Rectangle { color = spec.bg_color },
        {
            builder.Node(string.format("col gap-%d center", list_gap), nil, children),
        }
    ))
    return tree
end

function M.menu_tree(spec, cursor, on_tap)
    local tree = build_menu_tree(spec, cursor, on_tap)
    ui.DrawTree(tree)
    return tree
end

function M.draw_menu(spec, cursor)
    local tree = M.menu_tree(spec, cursor, nil)
    painter.DrawTree(tree)
end

function M.menu_hit_test(spec, cursor, on_tap, x, y)
    local tree = M.menu_tree(spec, cursor, on_tap)
    ui.Tap(tree, x, y)
end

local WIN_DIM_COLOR = { 255, 255, 255, 140 }
M.WIN_BG_COLOR = WIN_DIM_COLOR

local GAME_OVER_DIM_COLOR = { 61, 59, 51, 140 }
M.GAME_OVER_BG_COLOR = GAME_OVER_DIM_COLOR

local function draw_win_particles(particles)
    if not particles or #particles == 0 then return end
    local size  = config.PARTICLE.SIZE
    local w, h  = love.graphics.getDimensions()
    for _, p in ipairs(particles) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x * w, p.y * h, size, size)
    end
end

M.draw_win_particles = draw_win_particles

return M
