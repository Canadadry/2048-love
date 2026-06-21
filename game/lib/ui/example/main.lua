-- Run from: cd game && lua lib/ui/example/main.lua
--
-- Standalone demo of lib/ui: builds a small main-menu screen (title + three
-- buttons) using only lib/ui's builder DSL and painter module, then prints
-- the computed layout. Doesn't touch any of the game's own code (menu.lua,
-- renderer/, etc.) — this is what using lib/ui from scratch looks like.
-- No real LÖVE runtime needed — just enough of the love.graphics surface
-- for the painter module to run, same trick tests/test_all.lua uses.
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

local ui = require("lib.ui.layout.ui")
local builder = require("lib.ui.layout.builder")
local painter = require("lib.ui.painter.painter")

local SCREEN_W, SCREEN_H = love.graphics.getDimensions()

local function Button(label)
    return builder.Node(
        "w-240 h-60 center",
        painter.Rectangle { color = { 237, 227, 217, 255 }, rounded = 6, segment = 8 },
        { builder.Leaf("grow-x h-fit", painter.Text { text = label, align = "center" }) }
    )
end

local tree = painter.Tree()
builder.Build(tree, builder.Node(
    string.format("w-%d h-%d center", SCREEN_W, SCREEN_H),
    nil,
    {
        builder.Node("col gap-16 center", nil, {
            builder.Leaf("grow-x h-fit", painter.Text { text = "2048", align = "center" }),
            Button("New Game"),
            Button("Options"),
            Button("Quit"),
        }),
    }
))
ui.DrawTree(tree)

print("lib/ui main menu, computed via ui.DrawTree:")
for _, cmd in ipairs(tree.Commands) do
    print(string.format(
        "  %-9s x=%.0f y=%.0f w=%.0f h=%.0f",
        cmd.painter and cmd.painter.kind or "<group>",
        cmd.x, cmd.y, cmd.w, cmd.h
    ))
end
