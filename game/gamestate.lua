local config = require("config")
local grid   = require("grid")
local tile   = require("tile")

local M = {}
local State = {}
State.__index = State

local DIRS = { left=true, right=true, up=true, down=true }

local function make_state(g)
    local self   = setmetatable({}, State)
    self._grid   = g
    self._score  = 0
    self._win    = false
    self._over   = false
    self._frozen = false
    self._tiles  = {}
    return self
end

function M.new()
    return make_state(grid.new())
end

function M.new_from(cells)
    return make_state(grid.new_from(cells))
end

function State:is_animating()
    return #self._tiles > 0
end

function State:update(dt)
    if #self._tiles == 0 then return end
    for _, t in ipairs(self._tiles) do
        t:update(dt)
    end
    -- purge finished tiles; if all done, settle the board
    local any_alive = false
    for _, t in ipairs(self._tiles) do
        if not t:is_done() then any_alive = true; break end
    end
    if not any_alive then
        self._tiles = {}
    end
end

function State:keypressed(key)
    if self._frozen or self:is_animating() or not DIRS[key] then return end

    local result = self._grid:move(key)
    if result.moved then
        self._score = self._score + result.score_delta
        -- spawn is deferred until animation completes; for now spawn immediately
        -- (renderer will show static grid once tiles list empties)
        self._grid:spawn_tile()

        -- build tile animations from move descriptors
        -- pixel positions are not available here (no window); tiles carry
        -- row/col instead — renderer resolves to pixels each frame.
        -- We store col/row as proxies and resolve in renderer.
        for _, m in ipairs(result.moves) do
            self._tiles[#self._tiles + 1] = {
                value    = m.value,
                from_row = m.from_row, from_col = m.from_col,
                to_row   = m.to_row,   to_col   = m.to_col,
                _timer   = 0,
                _duration = config.ANIM_DURATION,
                is_done  = function(t) return t._timer >= t._duration end,
                update   = function(t, dt) t._timer = t._timer + dt end,
            }
        end
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
function State:anim_tiles() return self._tiles end

return M
