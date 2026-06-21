-- Run from: cd game && lua lib/ui/example/main.lua
--
-- Rebuilds the existing main-menu button list (menu.main_menu_button_bounds)
-- using lib/ui instead of hand-rolled pixel math, then prints both sets of
-- boxes so you can see they land on the exact same pixels. No real LÖVE
-- runtime needed — just enough of the love.graphics surface for the menu
-- and painter modules to run, same trick tests/test_all.lua uses.
love = {
    graphics = {
        getDimensions = function() return 600, 600 end,
        getFont = function()
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 14 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
        setColor  = function(...) end,
        rectangle = function(...) end,
        draw      = function(...) end,
        printf    = function(...) end,
    }
}

local menu = require("menu")
local ui = require("lib.ui.layout.ui")
local frame = require("lib.ui.layout.frame")
local painter = require("lib.ui.painter.painter")

-- The thing we're trying to replace: menu.lua re-derives board_metrics()
-- and manually offsets x/y for every button (see menu.lua's
-- main_menu_button_bounds()). This is the PRD's "Problem Statement".
local hand_rolled = menu.main_menu_button_bounds()

-- Pull the numbers menu.lua already computed instead of re-deriving them,
-- so this demo stays anchored to the real screen instead of made-up sizes.
local btn_w   = hand_rolled[1].w
local btn_h   = hand_rolled[1].h
local gap     = hand_rolled[2].y - (hand_rolled[1].y + hand_rolled[1].h)
local btn_x   = hand_rolled[1].x
local top_y   = hand_rolled[1].y
local total_h = btn_h * 3 + gap * 2

-- The lib/ui equivalent: one declarative tree instead of per-button math.
-- Each button is a Node (a Rectangle-painted box) with one Leaf child (the
-- centered label) — the same Node-wrapping-a-Leaf shape used for every
-- button in lib/ui's upstream example (see lib/ui/README.md).
local tree = painter.Tree()

ui.Node(tree, frame.Frame {
    pos    = frame.Pos(btn_x, top_y),      -- same top-left corner as the hand-rolled list
    size   = frame.Size(btn_w, total_h),   -- exact width/height of the button column
    layout = frame.Layout.Vertical(),      -- stack children top-to-bottom
    margin = gap,                          -- gap is the only "spacing" decision, made once
}, nil, function(tree)
    for _, b in ipairs(hand_rolled) do
        ui.Node(tree, frame.Frame {
            size    = frame.Size(btn_w, btn_h),
            align   = frame.Align(frame.Align.Middle(), frame.Align.Middle()),
            painter = painter.Rectangle { color = { 237, 227, 217, 255 }, rounded = 6, segment = 8 },
        }, nil, function(tree)
            ui.Leaf(tree, frame.Frame {
                size    = frame.Size(frame.Size.Grow(), frame.Size.Fit()),
                painter = painter.Text { text = b.label, align = "center" },
            })
        end)
    end
end)

ui.DrawTree(tree)

print("hand-rolled (menu.main_menu_button_bounds):")
for _, b in ipairs(hand_rolled) do
    print(string.format("  %-10s x=%d y=%d w=%d h=%d", b.label, b.x, b.y, b.w, b.h))
end

print("\nlib/ui (computed via ui.DrawTree):")
for _, cmd in ipairs(tree.Commands) do
    if cmd.painter and cmd.painter.kind == "Rectangle" then
        print(string.format("  rect       x=%.0f y=%.0f w=%.0f h=%.0f", cmd.x, cmd.y, cmd.w, cmd.h))
    end
end
