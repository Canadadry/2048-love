local config    = require("config")
local gamestate = require("gamestate")
local renderer  = require("renderer")

local state

function love.load()
    love.window.setTitle("2048")
    love.window.setMode(config.WINDOW_W, config.WINDOW_H, { resizable = true, minwidth = 300, minheight = 300 })
    love.graphics.setBackgroundColor(0.98, 0.97, 0.94)
    state = gamestate.new()
end

function love.update(_dt) end

function love.draw()
    renderer.draw(state:cells(), state:score(), state:game_over(), state:win())
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    state:keypressed(key)
end

function love.resize(_w, _h) end
