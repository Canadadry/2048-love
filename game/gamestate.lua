local config = require("config")
local check  = require("check")
local grid   = require("grid")
local tile   = require("tile")

local M = {}
local State = {}
State.__index = State

local DIRS = { left=true, right=true, up=true, down=true }

local function make_state(g)
    local self      = setmetatable({}, State)
    self._grid      = g
    self._score     = 0
    self._win       = false
    self._over      = false
    self._frozen    = false
    self._tiles     = {}
    self._queue     = {}
    self._win_seen  = false
    self._cursor    = 0
    return self
end

local function apply_move(self, dir)
    local result = self._grid:move(dir)
    if result.moved then
        self._score = self._score + result.score_delta
        self._grid:spawn_tile()
        for _, m in ipairs(result.moves) do
            self._tiles[#self._tiles + 1] = tile.new(
                m.value,
                m.from_row, m.from_col,
                m.to_row,   m.to_col,
                config.ANIM_DURATION
            )
        end
    end
    if result.win and not self._win_seen then
        self._win    = true
        self._frozen = true
    elseif result.game_over then
        self._over   = true
        self._frozen = true
    end
end

function M.new()
    return make_state(grid.new())
end

function M.new_from(cells)
    check.grid_cells(cells, config.GRID_SIZE, "cells")
    return make_state(grid.new_from(cells))
end

function State:is_animating()
    return #self._tiles > 0
end

function State:update(dt)
    if #self._tiles == 0 then
        if #self._queue > 0 and not self._frozen then
            apply_move(self, table.remove(self._queue, 1))
        end
        return
    end
    for _, t in ipairs(self._tiles) do
        t:update(dt)
    end
    local any_alive = false
    for _, t in ipairs(self._tiles) do
        if not t:is_done() then any_alive = true; break end
    end
    if not any_alive then
        self._tiles = {}
    end
end

function State:keypressed(key)
    if self._win then
        if key == "up" then
            self._cursor = math.max(0, self._cursor - 1)
        elseif key == "down" then
            self._cursor = math.min(1, self._cursor + 1)
        elseif key == "return" then
            if self._cursor == 0 then
                self:continue_game()
            else
                self:restart()
            end
        end
        return
    end
    if self._over then
        if key == "return" or DIRS[key] then self:restart() end
        return
    end
    if self._frozen or self:is_animating() or not DIRS[key] then return end
    apply_move(self, key)
end

function State:queue_move(dir)
    check.one_of(dir, DIRS, "dir")
    self._queue[#self._queue + 1] = dir
end

function State:continue_game()
    if not self._win then return end
    self._win      = false
    self._frozen   = false
    self._win_seen = true
    self._cursor   = 0
end

function State:restart()
    self._grid     = grid.new()
    self._score    = 0
    self._win      = false
    self._over     = false
    self._frozen   = false
    self._tiles    = {}
    self._queue    = {}
    self._win_seen = false
    self._cursor   = 0
end

function State:cells()      return self._grid:get_cells() end
function State:score()      return self._score end
function State:win()        return self._win end
function State:game_over()  return self._over end
function State:anim_tiles() return self._tiles end
function State:cursor()     return self._cursor end

return M
