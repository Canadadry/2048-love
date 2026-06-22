local menu = require("menu")

local M = {}
local Screen = {}

local DIRS = { left = true, right = true, up = true, down = true }

function M.new(host, game)
    return setmetatable({ host = host, game = game }, { __index = Screen })
end

local function restart(self)
    self.game:restart()
    self.host:dismiss()
end

function Screen:keypressed(key)
    if key == "return" or DIRS[key] then
        restart(self)
    end
end

function Screen:tap(x, y)
    menu.game_over_hit_test({ on_restart = function() restart(self) end }, x, y)
end

function Screen:draw()
    menu.draw_game_over()
end

function Screen:opaque()
    return false
end

return M
