local config       = require("config")
local check        = require("check")
local grid         = require("grid")
local tile         = require("tile")
local statemachine = require("statemachine")

local M    = {}
local DIRS = { left=true, right=true, up=true, down=true }

-- ── Shared context ─────────────────────────────────────────────────────────────

local function make_ctx(g)
    return {
        grid           = g,
        score          = 0,
        win_seen       = false,
        tiles          = {},
        queue          = {},
        quit_requested = false,
        switch         = nil,  -- set in build(), after sm is created
    }
end

-- ── Base state: default accessors shared by all states ─────────────────────────

local Base = {}
Base.__index = Base

function Base:score()          return self._ctx.score end
function Base:cells()          return self._ctx.grid:get_cells() end
function Base:anim_tiles()     return self._ctx.tiles end
function Base:is_animating()   return #self._ctx.tiles > 0 end
function Base:win()            return false end
function Base:game_over()      return false end
function Base:paused()         return false end
function Base:in_menu()        return false end
function Base:cursor()         return 0 end
function Base:pause_cursor()   return 0 end
function Base:menu_cursor()    return 0 end
function Base:quit_requested() return self._ctx.quit_requested end

-- No-op actions (safe to call from any state via the machine's __index)
function Base:resume()        end
function Base:continue_game() end
function Base:restart()       end
function Base:queue_move()    end

-- Default update: drain animation tiles (win/pause/game_over states inherit this)
function Base:update(dt)
    local ctx = self._ctx
    if #ctx.tiles == 0 then return end
    for _, t in ipairs(ctx.tiles) do t:update(dt) end
    local any_alive = false
    for _, t in ipairs(ctx.tiles) do
        if not t:is_done() then any_alive = true; break end
    end
    if not any_alive then ctx.tiles = {} end
end

-- ── apply_move (shared helper) ─────────────────────────────────────────────────

local function apply_move(ctx, dir)
    local result = ctx.grid:move(dir)
    if result.moved then
        ctx.score = ctx.score + result.score_delta
        ctx.grid:spawn_tile()
        for _, m in ipairs(result.moves) do
            ctx.tiles[#ctx.tiles + 1] = tile.new(
                m.value, m.from_row, m.from_col, m.to_row, m.to_col, config.ANIM_DURATION
            )
        end
    end
    if result.win and not ctx.win_seen then
        ctx.switch("win")
    elseif result.game_over then
        ctx.switch("game_over")
    end
end

-- ── restart (shared helper) ────────────────────────────────────────────────────

local function do_restart(ctx)
    ctx.grid     = grid.new()
    ctx.score    = 0
    ctx.win_seen = false
    ctx.tiles    = {}
    ctx.queue    = {}
    ctx.switch("playing")
end

-- ── menu_state ────────────────────────────────────────────────────────────────

local MenuState = setmetatable({}, Base)
MenuState.__index = MenuState

local function make_menu_state(ctx)
    return setmetatable({ _ctx = ctx, _cursor = 0 }, MenuState)
end

function MenuState:in_menu()     return true end
function MenuState:menu_cursor() return self._cursor end

function MenuState:keypressed(key)
    if key == "down" then
        self._cursor = math.min(1, self._cursor + 1)
    elseif key == "up" then
        self._cursor = math.max(0, self._cursor - 1)
    elseif key == "return" then
        if self._cursor == 0 then
            self._ctx.switch("playing")
        else
            self._ctx.quit_requested = true
        end
    end
end

-- ── win_state ─────────────────────────────────────────────────────────────────

local WinState = setmetatable({}, Base)
WinState.__index = WinState

local function make_win_state(ctx)
    return setmetatable({ _ctx = ctx, _cursor = 0 }, WinState)
end

function WinState:win()    return true end
function WinState:cursor() return self._cursor end

function WinState:enter()
    self._cursor = 0
end

function WinState:continue_game()
    self._ctx.win_seen = true
    self._ctx.switch("playing")
end

function WinState:restart()
    do_restart(self._ctx)
end

function WinState:keypressed(key)
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
end

-- ── game_over_state ───────────────────────────────────────────────────────────

local GameOverState = setmetatable({}, Base)
GameOverState.__index = GameOverState

local function make_game_over_state(ctx)
    return setmetatable({ _ctx = ctx }, GameOverState)
end

function GameOverState:game_over() return true end

function GameOverState:restart()
    do_restart(self._ctx)
end

function GameOverState:keypressed(key)
    if key == "return" or DIRS[key] then self:restart() end
end

-- ── paused_state ──────────────────────────────────────────────────────────────

local PausedState = setmetatable({}, Base)
PausedState.__index = PausedState

local function make_paused_state(ctx)
    return setmetatable({ _ctx = ctx, _cursor = 0 }, PausedState)
end

function PausedState:paused()       return true end
function PausedState:pause_cursor() return self._cursor end

function PausedState:enter()
    self._cursor = 0
end

function PausedState:resume()
    self._ctx.switch("playing")
end

function PausedState:restart()
    do_restart(self._ctx)
end

function PausedState:keypressed(key)
    if key == "up" then
        self._cursor = math.max(0, self._cursor - 1)
    elseif key == "down" then
        self._cursor = math.min(2, self._cursor + 1)
    elseif key == "escape" then
        self:resume()
    elseif key == "return" then
        if self._cursor == 0 then
            self:resume()
        elseif self._cursor == 1 then
            self:restart()
        elseif self._cursor == 2 then
            self._ctx.quit_requested = true
        end
    end
end

-- ── playing_state ─────────────────────────────────────────────────────────────

local PlayingState = setmetatable({}, Base)
PlayingState.__index = PlayingState

local function make_playing_state(ctx)
    return setmetatable({ _ctx = ctx, _pause_pending = false }, PlayingState)
end

function PlayingState:enter()
    self._pause_pending = false
end

function PlayingState:restart()
    do_restart(self._ctx)
end

function PlayingState:queue_move(dir)
    check.one_of(dir, DIRS, "dir")
    local q = self._ctx.queue
    q[#q + 1] = dir
end

function PlayingState:update(dt)
    local ctx = self._ctx
    if #ctx.tiles == 0 then
        if self._pause_pending then
            self._pause_pending = false
            ctx.queue = {}
            ctx.switch("paused")
            return
        end
        if #ctx.queue > 0 then
            apply_move(ctx, table.remove(ctx.queue, 1))
        end
        return
    end
    for _, t in ipairs(ctx.tiles) do t:update(dt) end
    local any_alive = false
    for _, t in ipairs(ctx.tiles) do
        if not t:is_done() then any_alive = true; break end
    end
    if not any_alive then
        ctx.tiles = {}
        if self._pause_pending then
            self._pause_pending = false
            ctx.queue = {}
            ctx.switch("paused")
        end
    end
end

function PlayingState:keypressed(key)
    local ctx = self._ctx
    if key == "escape" then
        if #ctx.tiles > 0 then
            self._pause_pending = true
        else
            ctx.queue = {}
            ctx.switch("paused")
        end
        return
    end
    if #ctx.tiles > 0 or not DIRS[key] then return end
    apply_move(ctx, key)
end

function PlayingState:resize(w, h)
    for _, t in ipairs(self._ctx.tiles) do t:finish() end
end

-- ── Factory ───────────────────────────────────────────────────────────────────

local function build(ctx, initial_name)
    local sm  -- forward declaration; captured by ctx.switch closure below

    local states = {
        menu      = make_menu_state(ctx),
        playing   = make_playing_state(ctx),
        paused    = make_paused_state(ctx),
        win       = make_win_state(ctx),
        game_over = make_game_over_state(ctx),
    }

    ctx.switch = function(name) sm:switch(states[name]) end

    sm = statemachine.new(states[initial_name])
    return sm
end

function M.new()
    return build(make_ctx(grid.new()), "menu")
end

function M.new_from(cells)
    check.grid_cells(cells, config.GRID_SIZE, "cells")
    return build(make_ctx(grid.new_from(cells)), "playing")
end

return M
