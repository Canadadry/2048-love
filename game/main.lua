local config    = require("config")
local gamestate = require("gamestate")
local menu      = require("menu")
local renderer  = require("renderer")
local swipe     = require("swipe")

local state
local swiper

function love.load()
    for _, v in ipairs(arg or {}) do
        local n = v:match("^%-%-win%-tile=(%d+)$")
        if n then config.WIN_TILE = tonumber(n); break end
    end
    love.window.setTitle("2048")
    love.window.setMode(config.WINDOW_W, config.WINDOW_H, { resizable = true, minwidth = 300, minheight = 300 })
    love.graphics.setBackgroundColor(0.98, 0.97, 0.94)
    renderer.load()
    state  = gamestate.new()
    local w, h = love.graphics.getDimensions()
    swiper = swipe.new(math.min(w, h) * 0.10)
end

function love.update(dt)
    state:update(dt)
    renderer.update(dt)
end

function love.draw()
    renderer.draw(state:cells(), state:score(), state:game_over(), state:win(), state:anim_tiles(), state:cursor(), state:paused(), state:pause_cursor())
end

function love.keypressed(key)
    state:keypressed(key)
    if state:quit_requested() then love.event.quit() end
end

function love.resize(w, h)
    for _, t in ipairs(state:anim_tiles()) do
        t:finish()
    end
    swiper:set_threshold(math.min(w, h) * 0.10)
end

local function hit(btn, x, y)
    return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
end

local function handle_tap(x, y)
    if not state:paused() and not state:win() and not state:game_over() then
        if hit(menu.pause_icon_bounds(), x, y) then
            state:keypressed("escape")
            return
        end
    end
    if state:paused() then
        local btns = menu.pause_button_bounds()
        if hit(btns[1], x, y) then
            state:resume()
        elseif hit(btns[2], x, y) then
            state:restart()
        elseif hit(btns[3], x, y) then
            love.event.quit()
        end
    elseif state:win() then
        local b = menu.win_button_bounds()
        if hit(b.continue_btn, x, y) then
            state:continue_game()
        elseif hit(b.restart_btn, x, y) then
            state:restart()
        end
    elseif state:game_over() then
        if hit(menu.game_over_button_bounds(), x, y) then
            state:restart()
        end
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    swiper:touchpressed("mouse", x, y)
    handle_tap(x, y)
end

function love.mousemoved(x, y)
    local dir = swiper:touchmoved("mouse", x, y)
    if dir and not state:game_over() and not state:win() then
        state:queue_move(dir)
    end
end

function love.mousereleased(x, y, button)
    if button ~= 1 then return end
    local dir = swiper:touchreleased("mouse", x, y)
    if dir and not state:game_over() and not state:win() then
        state:queue_move(dir)
    end
end

function love.touchpressed(id, x, y)
    swiper:touchpressed(id, x, y)
end

function love.touchmoved(id, x, y)
    local dir = swiper:touchmoved(id, x, y)
    if dir and not state:game_over() and not state:win() then
        state:queue_move(dir)
    end
end

function love.touchreleased(id, x, y)
    local dir = swiper:touchreleased(id, x, y)
    if dir then
        if not state:game_over() and not state:win() then
            state:queue_move(dir)
        end
    else
        handle_tap(x, y)
    end
end
