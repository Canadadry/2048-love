local config       = require("config")
local check        = require("check")
local grid         = require("grid")
local tile         = require("tile")
local particle     = require("particle")
local statemachine = require("statemachine")
local options      = require("options")

local M    = {}
local DIRS = { left=true, right=true, up=true, down=true }

local function make_ctx(g)
    return {
        grid           = g,
        score          = 0,
        win_seen       = false,
        tiles          = {},
        win_particles  = {},
        queue          = {},
        quit_requested = false,
    }
end

local Base = {}
Base.__index = Base

function Base:score()          return self._ctx.score end
function Base:cells()          return self._ctx.grid:get_cells() end
function Base:anim_tiles()     return self._ctx.tiles end
function Base:win_particles()  return self._ctx.win_particles end
function Base:is_animating()   return #self._ctx.tiles > 0 end
function Base:win()            return false end
function Base:game_over()      return false end
function Base:paused()         return false end
function Base:in_menu()        return false end
function Base:in_options()     return false end
function Base:win_tile()       return config.WIN_TILE end
function Base:theme()          return config.TILESET end
function Base:animations_enabled() return config.ANIMATIONS_ENABLED end
function Base:effects_enabled()    return config.EFFECTS_ENABLED end
function Base:focused_row()    return 0 end
function Base:cursor()         return 0 end
function Base:pause_cursor()   return 0 end
function Base:menu_cursor()    return 0 end
function Base:quit_requested() return self._ctx.quit_requested end
function Base:resume()        end
function Base:continue_game() end
function Base:restart()       end
function Base:to_main_menu()  end
function Base:select_menu_item() end
function Base:queue_move()    end

local function update_particles(ctx, dt)
    if #ctx.win_particles == 0 then return end
    local alive = {}
    for _, p in ipairs(ctx.win_particles) do
        p:update(dt)
        if not p:is_dead() then alive[#alive + 1] = p end
    end
    ctx.win_particles = alive
end

function Base:update(dt)
    local ctx = self._ctx
    update_particles(ctx, dt)
    if #ctx.tiles == 0 then return end
    for _, t in ipairs(ctx.tiles) do t:update(dt) end
    local any_alive = false
    for _, t in ipairs(ctx.tiles) do
        if not t:is_done() then any_alive = true; break end
    end
    if not any_alive then ctx.tiles = {} end
end

local function apply_move(ctx, dir)
    local result = ctx.grid:move(dir)
    if result.moved then
        ctx.score = ctx.score + result.score_delta
        ctx.grid:spawn_tile()
        if config.ANIMATIONS_ENABLED then
            for _, m in ipairs(result.moves) do
                ctx.tiles[#ctx.tiles + 1] = tile.new(
                    m.value, m.from_row, m.from_col, m.to_row, m.to_col, config.ANIM_DURATION,
                    m.merged and config.EFFECTS_ENABLED
                )
            end
        end
    end
    if result.win and not ctx.win_seen then
        ctx.switch("win")
    elseif result.game_over then
        ctx.switch("game_over")
    end
end

local function do_restart(ctx)
    ctx.grid          = grid.new()
    ctx.score         = 0
    ctx.win_seen      = false
    ctx.tiles         = {}
    ctx.win_particles = {}
    ctx.queue         = {}
    ctx.switch("playing")
end

local MenuState = setmetatable({}, Base)
MenuState.__index = MenuState

local function make_menu_state(ctx)
    return setmetatable({ _ctx = ctx, _cursor = 0 }, MenuState)
end

function MenuState:in_menu()     return true end
function MenuState:menu_cursor() return self._cursor end

local function perform_menu_item(ctx, index)
    if index == 0 then
        -- must reset via do_restart, not a bare switch: ctx may carry a
        -- stale in-progress board if the player reached this menu via
        -- the pause screen's "Main Menu" option rather than fresh launch.
        do_restart(ctx)
    elseif index == 1 then
        ctx.switch("options")
    else
        ctx.quit_requested = true
    end
end

function MenuState:keypressed(key)
    if key == "down" then
        self._cursor = math.min(2, self._cursor + 1)
    elseif key == "up" then
        self._cursor = math.max(0, self._cursor - 1)
    elseif key == "return" then
        perform_menu_item(self._ctx, self._cursor)
    end
end

function MenuState:select_menu_item(index)
    self._cursor = index
    perform_menu_item(self._ctx, index)
end

local WinState = setmetatable({}, Base)
WinState.__index = WinState

local function make_win_state(ctx)
    return setmetatable({ _ctx = ctx }, WinState)
end

function WinState:win()    return true end
function WinState:cursor() return self._cursor end

function WinState:enter()
    self._cursor = 0
    self._ctx.win_particles = config.EFFECTS_ENABLED and particle.spawn() or {}
end

function WinState:continue_game()
    self._ctx.win_seen      = true
    self._ctx.win_particles = {}
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

local PausedState = setmetatable({}, Base)
PausedState.__index = PausedState

local function make_paused_state(ctx)
    return setmetatable({ _ctx = ctx }, PausedState)
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

function PausedState:to_main_menu()
    self._ctx.switch("menu")
end

function PausedState:keypressed(key)
    if key == "up" then
        self._cursor = math.max(0, self._cursor - 1)
    elseif key == "down" then
        self._cursor = math.min(3, self._cursor + 1)
    elseif key == "escape" then
        self:resume()
    elseif key == "return" then
        if self._cursor == 0 then
            self:resume()
        elseif self._cursor == 1 then
            self:restart()
        elseif self._cursor == 2 then
            self:to_main_menu()
        elseif self._cursor == 3 then
            self._ctx.quit_requested = true
        end
    end
end

local PlayingState = setmetatable({}, Base)
PlayingState.__index = PlayingState

local function make_playing_state(ctx)
    return setmetatable({ _ctx = ctx }, PlayingState)
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

function PlayingState:resize()
    for _, t in ipairs(self._ctx.tiles) do t:finish() end
end

local function build(ctx, initial_name)
    local sm

    local states = {
        menu      = make_menu_state(ctx),
        playing   = make_playing_state(ctx),
        paused    = make_paused_state(ctx),
        win       = make_win_state(ctx),
        game_over = make_game_over_state(ctx),
        options   = options.new(ctx, Base),
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
