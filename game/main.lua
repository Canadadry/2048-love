local config         = require("config")
local i18n           = require("lib.i18n")
local screen_manager = require("lib.screen_manager")
local swipe          = require("lib.swipe")
local settings       = require("lib.settings")
local sound          = require("lib.sound")

local GAMEPAD_KEY = {
    a            = "return",
    b            = "escape",
    start        = "escape",
    leftshoulder = "return",
    dpup         = "up",
    dpdown       = "down",
    dpleft       = "left",
    dpright      = "right",
}
local AXIS_DEADZONE   = 0.5
local axis_triggered  = {}

local SCREENS = {
    main_menu = require("screens.main_menu_screen"),
    loading   = require("screens.loading_screen"),
    game      = require("screens.game_screen"),
    pause     = require("screens.pause_screen"),
    win       = require("screens.win_screen"),
    game_over = require("screens.game_over_screen"),
    options   = require("screens.options_screen"),
}

local host
local swiper

function love.load()
    love.filesystem.setIdentity("2048")
    settings.load()
    local csv = love.filesystem.read(config.LANG_FILE)
    i18n.load(csv or "key,en\nlang.name,English")
    i18n.set_lang(settings.get("language", config.DEFAULT_LANG))
    config.WIN_TILE          = settings.get("win_tile", config.WIN_TILE)
    config.TILESET           = settings.get("theme", config.TILESET)
    config.ANIMATIONS_ENABLED = settings.get("animations_enabled", config.ANIMATIONS_ENABLED)
    config.EFFECTS_ENABLED    = settings.get("effects_enabled", config.EFFECTS_ENABLED)
    config.SOUND.ENABLED      = settings.get("sound_enabled", config.SOUND.ENABLED)
    config.MUSIC.ENABLED      = settings.get("music_enabled", config.MUSIC.ENABLED)
    for _, v in ipairs(arg or {}) do
        local n = v:match("^%-%-win%-tile=(%d+)$")
        if n then
            config.WIN_TILE = tonumber(n); break
        end
    end
    love.window.setTitle("2048")
    love.window.setMode(config.WINDOW_W, config.WINDOW_H, { resizable = true, minwidth = 300, minheight = 300 })
    love.graphics.setBackgroundColor(0.98, 0.97, 0.94)
    host = screen_manager.new(nil, SCREENS, {
        on_transition = function()
            if config.SOUND.ENABLED then sound.play(config.SOUND.TRANSITION) end
        end,
        ease_fn = config.TRANSITION_EASE,
    })
    host:replace(host:spawn("main_menu"))
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
    if host:is_transitioning() then return end
    local screen = host:top()
    if screen.mousepressed then screen:mousepressed(x, y, button, istouch); return end
    if istouch then return end
    if button ~= 1 then return end
    swiper:touchpressed("mouse", x, y)
end

function love.mousemoved(x, y, dx, dy, istouch)
    if host:is_transitioning() then return end
    local screen = host:top()
    if screen.mousemoved then screen:mousemoved(x, y, dx, dy, istouch); return end
    if istouch then return end
    swiper:touchmoved("mouse", x, y)
end

function love.mousereleased(x, y, button, istouch)
    if host:is_transitioning() then return end
    local screen = host:top()
    if screen.mousereleased then screen:mousereleased(x, y, button, istouch); return end
    if istouch then return end
    if button ~= 1 then return end
    local _, is_tap = swiper:touchreleased("mouse", x, y)
    if is_tap then screen:tap(x, y) end
end

function love.touchpressed(id, x, y)
    if host:is_transitioning() then return end
    local screen = host:top()
    if screen.touchpressed then screen:touchpressed(id, x, y); return end
    swiper:touchpressed(id, x, y)
end

function love.touchmoved(id, x, y)
    if host:is_transitioning() then return end
    local screen = host:top()
    if screen.touchmoved then screen:touchmoved(id, x, y); return end
    swiper:touchmoved(id, x, y)
end

function love.touchreleased(id, x, y)
    if host:is_transitioning() then return end
    local screen = host:top()
    if screen.touchreleased then screen:touchreleased(id, x, y); return end
    local _, is_tap = swiper:touchreleased(id, x, y)
    if is_tap then screen:tap(x, y) end
end

function love.gamepadpressed(_, button)
    local key = GAMEPAD_KEY[button]
    if key then love.keypressed(key) end
end

function love.gamepadaxis(joystick, axis, value)
    local id = tostring(joystick:getID())

    if axis == "triggerleft" then
        local tid = id .. "triggerleft"
        if value > AXIS_DEADZONE then
            if not axis_triggered[tid] then
                axis_triggered[tid] = true
                love.keypressed("escape")
            end
        else
            axis_triggered[tid] = nil
        end
        return
    end

    if axis ~= "leftx" and axis ~= "lefty" and axis ~= "rightx" and axis ~= "righty" then return end
    local neg_id  = id .. axis .. "-"
    local pos_id  = id .. axis .. "+"
    local is_x    = axis == "leftx" or axis == "rightx"
    local neg_key = is_x and "left" or "up"
    local pos_key = is_x and "right" or "down"
    if value < -AXIS_DEADZONE then
        if not axis_triggered[neg_id] then
            axis_triggered[neg_id] = true
            axis_triggered[pos_id] = nil
            love.keypressed(neg_key)
        end
    elseif value > AXIS_DEADZONE then
        if not axis_triggered[pos_id] then
            axis_triggered[pos_id] = true
            axis_triggered[neg_id] = nil
            love.keypressed(pos_key)
        end
    else
        axis_triggered[neg_id] = nil
        axis_triggered[pos_id] = nil
    end
end
