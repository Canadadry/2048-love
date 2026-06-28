local config      = require("config")
local tile_draw   = require("tile_draw")
local transitions = require("lib.transitions")
local bg_picker   = require("lib.bg_picker")

local PUSH_FWD     = transitions.push("left")
local T_DUR        = config.TRANSITION_DURATION
local BOUNCE_SPEED = 0.6   -- seconds to cross the track once

local BG    = { 0.98, 0.97, 0.94 }
local TRACK = { 0.80, 0.75, 0.70 }
local PILL  = { 0.96, 0.49, 0.37 }

local M = {}
local Screen = {}

function M.new(host)
    local name = config.TILESET

    if name == "" then
        return require("screens.game_screen").new(host)
    end

    local thread = love.thread.newThread("lib/tileset_thread.lua")
    local ch_in  = love.thread.getChannel("tileset_loader_in")
    local ch_out = love.thread.getChannel("tileset_loader_out")
    ch_in:clear()
    ch_out:clear()
    ch_in:push("assets/" .. name .. ".png")
    thread:start()

    local bg_path = bg_picker.pick("assets/Bg")
    local bg_img  = bg_path and love.graphics.newImage(bg_path)

    return setmetatable({
        host    = host,
        _name   = name,
        _thread = thread,
        _ch_out = ch_out,
        _pos    = 0,
        _dir    = 1,
        _loaded = false,
        _bg     = bg_img,
    }, { __index = Screen })
end

function Screen:enter() end

function Screen:update(dt)
    self._pos = self._pos + self._dir * dt / BOUNCE_SPEED
    if self._pos >= 1 then self._pos = 1; self._dir = -1 end
    if self._pos <= 0 then self._pos = 0; self._dir =  1 end

    if not self._loaded then
        local result = self._ch_out:pop()
        if result ~= nil then
            self._thread:wait()
            if result then tile_draw.finish_tileset(self._name, result) end
            self._loaded = true
        elseif not self._thread:isRunning() then
            self._loaded = true
        end
    end

    if self._loaded and not self.host:is_transitioning() then
        self.host:replace(self.host:spawn("game"), PUSH_FWD, T_DUR)
    end
end

function Screen:draw()
    local w, h    = love.graphics.getDimensions()
    local track_w = math.floor(w * 0.4)
    local track_h = 8
    local pill_w  = math.floor(track_w * 0.25)
    local track_x = math.floor((w - track_w) / 2)
    local track_y = math.floor(h / 2) - math.floor(track_h / 2)

    if self._bg then
        local iw, ih = self._bg:getDimensions()
        local bx, by, bs = bg_picker.fit_cover(iw, ih, w, h, config.BG_ZOOM)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self._bg, bx, by, 0, bs, bs)
    else
        love.graphics.setColor(BG)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end

    love.graphics.setColor(TRACK)
    love.graphics.rectangle("fill", track_x, track_y, track_w, track_h, 4, 4)

    local pill_x = track_x + math.floor(self._pos * (track_w - pill_w))
    love.graphics.setColor(PILL)
    love.graphics.rectangle("fill", pill_x, track_y, pill_w, track_h, 4, 4)

    love.graphics.setColor(1, 1, 1)
end

function Screen:exit()
    self._thread:wait()
end

function Screen:keypressed(key) end
function Screen:resize(w, h)   end
function Screen:tap(x, y)      end

return M
