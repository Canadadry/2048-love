local grid = require("src.grid")

local M = {}
local State = {}
State.__index = State

local DIRS = { left=true, right=true, up=true, down=true }

function M.new()
    local self   = setmetatable({}, State)
    self._grid   = grid.new()
    self._score  = 0
    self._win    = false
    self._over   = false
    self._frozen = false
    return self
end

function State:keypressed(key)
    if self._frozen or not DIRS[key] then return end

    local result = self._grid:move(key)
    if result.moved then
        self._score = self._score + result.score_delta
        self._grid:spawn_tile()
    end

    if result.win then
        self._win    = true
        self._frozen = true
    elseif self._grid:is_game_over() then
        self._over   = true
        self._frozen = true
    end
end

function State:cells()     return self._grid:get_cells() end
function State:score()     return self._score end
function State:win()       return self._win end
function State:game_over() return self._over end

return M
