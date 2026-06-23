local check        = require("lib.check")
local config       = require("config")
local grid         = require("grid")
local tile         = require("tile")
local board        = require("board")
local tile_draw    = require("tile_draw")
local hud          = require("hud")
local font_cache   = require("lib.font_cache")
local swipe        = require("lib.swipe")

local M = {}
local Screen = {}

local DIRS = { left = true, right = true, up = true, down = true }
local get_font = font_cache.get_font

local function cell_key(r, c, n)
    return (r - 1) * n + c
end

function M.new(host, cells, rand)
    local g = cells and grid.new_from(cells, rand) or grid.new(rand)
    local w, h = love.graphics.getDimensions()
    return setmetatable({
        host    = host,
        _rand   = rand,
        _grid   = g,
        _score  = 0,
        _tiles  = {},
        _queue  = {},
        _swipe  = swipe.new(math.min(w, h) * 0.10),
    }, { __index = Screen })
end

function Screen:restart()
    self._grid          = grid.new(self._rand)
    self._score         = 0
    self._tiles         = {}
    self._queue         = {}
    self._win_seen      = false
    self._pause_pending = false
end

function Screen:mark_win_seen() self._win_seen = true end

function Screen:score()        return self._score end
function Screen:cells()        return self._grid:get_cells() end
function Screen:anim_tiles()   return self._tiles end
function Screen:is_animating() return #self._tiles > 0 end

local function apply_move(self, dir)
    local result = self._grid:move(dir)
    if result.moved then
        self._score = self._score + result.score_delta
        self._grid:spawn_tile()
        if config.ANIMATIONS_ENABLED then
            for _, m in ipairs(result.moves) do
                self._tiles[#self._tiles + 1] = tile.new(
                    m.value, m.from_row, m.from_col, m.to_row, m.to_col, config.ANIM_DURATION,
                    m.merged and config.EFFECTS_ENABLED
                )
            end
        end
    end
    if result.win and not self._win_seen then
        self.host:promote(self.host:spawn("win", self))
    elseif result.game_over then
        self.host:promote(self.host:spawn("game_over", self))
    end
end

function Screen:queue_move(dir)
    check.one_of(dir, DIRS, "dir")
    local q = self._queue
    q[#q + 1] = dir
end

-- Ticks every in-flight tile, clears self._tiles once none remain, and
-- reports whether any tile was still animating (before the clear).
local function advance_tiles(self, dt)
    for _, t in ipairs(self._tiles) do t:update(dt) end
    local any_alive = false
    for _, t in ipairs(self._tiles) do
        if not t:is_done() then any_alive = true; break end
    end
    if not any_alive then self._tiles = {} end
    return any_alive
end

local function open_pause(self)
    self._queue = {}
    self.host:promote(self.host:spawn("pause", self))
end

function Screen:update(dt)
    tile_draw.update(dt)
    if #self._tiles == 0 then
        if self._pause_pending then
            self._pause_pending = false
            open_pause(self)
            return
        end
        if #self._queue > 0 then
            apply_move(self, table.remove(self._queue, 1))
        end
        return
    end
    local any_alive = advance_tiles(self, dt)
    if not any_alive and self._pause_pending then
        self._pause_pending = false
        open_pause(self)
    end
end

function Screen:tap(x, y)
    hud.hit_test(self:score(), { on_pause_tap = function() open_pause(self) end }, x, y)
end

local function resolve_release(self, dir, is_tap, x, y)
    if dir then
        self:queue_move(dir)
    elseif is_tap then
        self:tap(x, y)
    end
end

function Screen:mousepressed(x, y, button, istouch)
    if istouch then return end
    if button ~= 1 then return end
    self._swipe:touchpressed("mouse", x, y)
end

function Screen:mousemoved(x, y, dx, dy, istouch)
    if istouch then return end
    local dir = self._swipe:touchmoved("mouse", x, y)
    if dir then self:queue_move(dir) end
end

function Screen:mousereleased(x, y, button, istouch)
    if istouch then return end
    if button ~= 1 then return end
    local dir, is_tap = self._swipe:touchreleased("mouse", x, y)
    resolve_release(self, dir, is_tap, x, y)
end

function Screen:touchpressed(id, x, y)
    self._swipe:touchpressed(id, x, y)
end

function Screen:touchmoved(id, x, y)
    local dir = self._swipe:touchmoved(id, x, y)
    if dir then self:queue_move(dir) end
end

function Screen:touchreleased(id, x, y)
    local dir, is_tap = self._swipe:touchreleased(id, x, y)
    resolve_release(self, dir, is_tap, x, y)
end

function Screen:resize(w, h)
    for _, t in ipairs(self._tiles) do t:finish() end
end

function Screen:resume()
    local w, h = love.graphics.getDimensions()
    self._swipe:set_threshold(math.min(w, h) * 0.10)
end

function Screen:draw()
    tile_draw.set_tileset(config.TILESET)

    local cells      = self:cells()
    local anim_tiles = self:anim_tiles()
    local board_px, tile_px, pad, board_x, board_y = board.metrics()
    local n       = config.GRID_SIZE
    local font_sz = math.max(12, math.floor(tile_px * 0.30))
    local font    = get_font(font_sz)

    board.draw_background(board_x, board_y, board_px)
    love.graphics.setFont(font)

    local dest = {}
    for _, t in ipairs(anim_tiles) do
        dest[cell_key(t.to_row, t.to_col, n)] = true
    end

    for r = 1, n do
        for c = 1, n do
            local px, py = board.cell_to_px(r, c, tile_px, pad, board_x, board_y)
            local val = dest[cell_key(r, c, n)] and 0 or cells[r][c]
            tile_draw.draw(val, px, py, tile_px, pad, font)
        end
    end

    for _, t in ipairs(anim_tiles) do
        local progress = t:progress()
        local fx, fy   = board.cell_to_px(t.from_row, t.from_col, tile_px, pad, board_x, board_y)
        local tx, ty   = board.cell_to_px(t.to_row,   t.to_col,   tile_px, pad, board_x, board_y)
        local px = math.floor(fx + (tx - fx) * progress)
        local py = math.floor(fy + (ty - fy) * progress)
        tile_draw.draw(t.value, px, py, tile_px, pad, font, t.scale)
    end

    hud.draw(self:score())
end

function Screen:keypressed(key)
    if key == "escape" then
        if #self._tiles > 0 then
            self._pause_pending = true
        else
            open_pause(self)
        end
        return
    end
    if #self._tiles > 0 or not DIRS[key] then return end
    apply_move(self, key)
end

return M
