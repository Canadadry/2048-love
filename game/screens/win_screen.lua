local menu        = require("menu")
local config      = require("config")
local particle    = require("particle")
local menu_screen = require("menu_screen")

local M = {}
local Screen = {}

function M.new(host, game)
    local self = setmetatable({ host = host, game = game }, { __index = Screen })
    self._mixin = menu_screen.new({
        items = {
            { label = "Continue",  on_activate = function() game:mark_win_seen(); host:dismiss() end },
            { label = "Restart",   on_activate = function() game:restart(); host:dismiss() end },
            { label = "Main Menu", on_activate = function() host:replace(host:spawn("main_menu")) end },
        },
    })
    return self
end

function Screen:enter()
    self._mixin:enter()
    self._particles = config.EFFECTS_ENABLED and particle.spawn() or {}
end

function Screen:win_particles()
    return self._particles
end

function Screen:update(dt)
    if #self._particles == 0 then return end
    local alive = {}
    for _, p in ipairs(self._particles) do
        p:update(dt)
        if not p:is_dead() then alive[#alive + 1] = p end
    end
    self._particles = alive
end

function Screen:cursor()
    return self._mixin:cursor()
end

function Screen:keypressed(key)
    self._mixin:keypressed(key)
end

function Screen:spec()
    return {
        title             = "You Win!",
        title_font_offset = 8,
        bg_color          = menu.WIN_BG_COLOR,
        item_style        = "button",
        items             = self._mixin:items(),
    }
end

function Screen:tap(x, y)
    menu.menu_hit_test(self:spec(), self:cursor(), function(i) self._mixin:tap(i) end, x, y)
end

function Screen:draw()
    menu.draw_menu(self:spec(), self:cursor())
    menu.draw_win_particles(self._particles)
end

function Screen:opaque()
    return false
end

return M
