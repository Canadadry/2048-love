local builder = require("lib.ui.layout.builder")
local ui      = require("lib.ui.layout.ui")
local painter = require("lib.ui.painter.painter")
local board   = require("renderer.board")

local M = {}

local SCORE_TEXT_COLOR = { 120, 110, 102, 255 }

local font_cache = {}
local function get_font(size)
    if not font_cache[size] then
        font_cache[size] = love.graphics.newFont(size)
    end
    return font_cache[size]
end

local function icon_size(tile_px)
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    return math.max(44, font_sz + 8)
end

local function draw_icon(_, x, y, w, h)
    local bar_w   = math.max(3, math.floor(w * 0.15))
    local bar_h   = math.floor(h * 0.50)
    local gap     = math.floor(w * 0.18)
    local total_w = bar_w * 2 + gap
    local bar_x   = x + math.floor((w - total_w) / 2)
    local bar_y   = y + math.floor((h - bar_h) / 2)

    love.graphics.setColor(0.47, 0.43, 0.40, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.90)
    love.graphics.rectangle("fill", bar_x,               bar_y, bar_w, bar_h)
    love.graphics.rectangle("fill", bar_x + bar_w + gap, bar_y, bar_w, bar_h)
end

local function icon_node(sz, on_pause_tap)
    return builder.Node(
        string.format("w-%d h-%d", sz, sz),
        painter.Group {
            painters = {
                painter.Object {
                    draw = draw_icon,
                    -- Object's contract is inconsistent: painter.Measure calls
                    -- measure(data) expecting {x,y}, painter.Wrap calls
                    -- measure(data, width) expecting a plain number. The icon
                    -- is Fixed-sized so neither return value is actually used.
                    measure = function(_, width) return width and 0 or { x = 0, y = 0 } end,
                },
                painter.Interactive { onTap = on_pause_tap },
            },
        },
        {}
    )
end

function M.hud_tree(score, show_icon, callbacks)
    callbacks = callbacks or {}
    local board_px, tile_px, pad, board_x, board_y = board.metrics()
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local font    = get_font(font_sz)
    local sz      = icon_size(tile_px)
    local row_y   = board_y - pad - sz

    local children = {
        builder.Leaf("grow-x h-fit", painter.Text {
            text  = "Score: " .. score,
            align = "left",
            font  = font,
            color = SCORE_TEXT_COLOR,
        }),
    }
    if show_icon then
        table.insert(children, icon_node(sz, callbacks.on_pause_tap))
    end

    local tree = painter.Tree()
    builder.Build(tree, builder.Node(
        string.format("x-%d y-%d row w-%d h-fit ay-center pr-%d", board_x, row_y, board_px, pad),
        nil,
        children
    ))
    ui.DrawTree(tree)
    return tree
end

function M.draw(score, show_icon)
    local tree = M.hud_tree(score, show_icon, nil)
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter then
            painter.Draw(cmd, cmd.painter)
        end
    end
end

function M.hit_test(score, show_icon, callbacks, x, y)
    local tree = M.hud_tree(score, show_icon, callbacks)
    local cb = ui.HitTest(tree, x, y)
    if cb then
        cb()
    end
end

return M
