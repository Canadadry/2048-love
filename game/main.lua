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

function love.update(dt)
    state:update(dt)
end

function love.draw()
    renderer.draw(state:cells(), state:score(), state:game_over(), state:win(), state:anim_tiles())
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    state:keypressed(key)
end

function love.resize(_w, _h)
    -- snap all in-flight animations to their targets on resize
    for _, t in ipairs(state:anim_tiles()) do
        t._timer = t._duration
    end
end
