local menu     = require("menu")
local config   = require("config")
local particle = require("particle")

local M = {}
local Screen = {}

function M.new(host, game)
    return setmetatable({ host = host, game = game }, { __index = Screen })
end

function Screen:enter()
    self._cursor    = 0
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
    return self._cursor
end

local function activate(self, cursor)
    if cursor == 0 then
        self.game:mark_win_seen()
        self.host:dismiss()
    else
        self.game:restart()
        self.host:dismiss()
    end
end

function Screen:keypressed(key)
    if key == "up" then
        self._cursor = math.max(0, self._cursor - 1)
    elseif key == "down" then
        self._cursor = math.min(1, self._cursor + 1)
    elseif key == "return" then
        activate(self, self._cursor)
    end
end

function Screen:tap(x, y)
    menu.win_hit_test(self._cursor, {
        on_continue = function() activate(self, 0) end,
        on_restart  = function() activate(self, 1) end,
    }, x, y)
end

function Screen:draw()
    menu.draw_win(self._cursor, self._particles)
end

function Screen:opaque()
    return false
end

return M
