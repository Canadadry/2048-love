local config            = require("config")
local screen_manager    = require("screen_manager")
local main_menu_screen   = require("screens.main_menu_screen")
local game_screen       = require("screens.game_screen")
local win_screen        = require("screens.win_screen")
local game_over_screen  = require("screens.game_over_screen")
local swipe             = require("swipe")
local settings          = require("settings")

local host
local swiper

local function make_main_menu()
    return main_menu_screen.new(host, function() return game_screen.new(host, {
        make_main_menu = make_main_menu,
        make_win       = function(game) return win_screen.new(host, game) end,
        make_game_over = function(game) return game_over_screen.new(host, game) end,
    }) end)
end

function love.load()
    love.filesystem.setIdentity("2048")
    settings.load()
    config.WIN_TILE          = settings.get("win_tile", config.WIN_TILE)
    config.TILESET           = settings.get("theme", config.TILESET)
    config.ANIMATIONS_ENABLED = settings.get("animations_enabled", config.ANIMATIONS_ENABLED)
    config.EFFECTS_ENABLED    = settings.get("effects_enabled", config.EFFECTS_ENABLED)
    for _, v in ipairs(arg or {}) do
        local n = v:match("^%-%-win%-tile=(%d+)$")
        if n then
            config.WIN_TILE = tonumber(n); break
        end
    end
    love.window.setTitle("2048")
    love.window.setMode(config.WINDOW_W, config.WINDOW_H, { resizable = true, minwidth = 300, minheight = 300 })
    love.graphics.setBackgroundColor(0.98, 0.97, 0.94)
    host = screen_manager.new(nil)
    host:replace(make_main_menu())
    local w, h = love.graphics.getDimensions()
    swiper     = swipe.new(math.min(w, h) * 0.10)
end

function love.update(dt)
    host:update(dt)
end

function love.draw()
    host:draw()
end

function love.keypressed(key)
    host:keypressed(key)
end

function love.resize(w, h)
    host:resize(w, h)
    swiper:set_threshold(math.min(w, h) * 0.10)
end

function love.mousepressed(x, y, button, istouch)
    if host.mousepressed then host:mousepressed(x, y, button, istouch); return end
    if istouch then return end
    if button ~= 1 then return end
    swiper:touchpressed("mouse", x, y)
end

function love.mousemoved(x, y, dx, dy, istouch)
    if host.mousemoved then host:mousemoved(x, y, dx, dy, istouch); return end
    if istouch then return end
    swiper:touchmoved("mouse", x, y)
end

function love.mousereleased(x, y, button, istouch)
    if host.mousereleased then host:mousereleased(x, y, button, istouch); return end
    if istouch then return end
    if button ~= 1 then return end
    local _, is_tap = swiper:touchreleased("mouse", x, y)
    if is_tap then host:tap(x, y) end
end

function love.touchpressed(id, x, y)
    if host.touchpressed then host:touchpressed(id, x, y); return end
    swiper:touchpressed(id, x, y)
end

function love.touchmoved(id, x, y)
    if host.touchmoved then host:touchmoved(id, x, y); return end
    swiper:touchmoved(id, x, y)
end

function love.touchreleased(id, x, y)
    if host.touchreleased then host:touchreleased(id, x, y); return end
    local _, is_tap = swiper:touchreleased(id, x, y)
    if is_tap then host:tap(x, y) end
end
