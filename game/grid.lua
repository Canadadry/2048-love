local unpack = table.unpack or unpack  -- Lua 5.1 (LuaJIT) vs 5.2+
local config = require("config")
local check  = require("check")

local M = {}
local Grid = {}
Grid.__index = Grid

local SIZE = config.GRID_SIZE

local function empty_board()
    local board = {}
    for r = 1, SIZE do
        board[r] = {}
        for c = 1, SIZE do
            board[r][c] = 0
        end
    end
    return board
end

local function empty_cells(board)
    local cells = {}
    for r = 1, SIZE do
        for c = 1, SIZE do
            if board[r][c] == 0 then
                cells[#cells + 1] = {r, c}
            end
        end
    end
    return cells
end

local function spawn_one(board, rand)
    local empty = empty_cells(board)
    if #empty == 0 then return end
    local pos = empty[rand(#empty)]
    board[pos[1]][pos[2]] = rand() < 0.9 and 2 or 4
end

function M.new(rand)
    rand = rand or math.random
    local self = setmetatable({}, Grid)
    self._board = empty_board()
    self._rand  = rand
    spawn_one(self._board, rand)
    spawn_one(self._board, rand)
    return self
end

function M.new_from(cells, rand)
    check.grid_cells(cells, SIZE, "cells")
    local self = setmetatable({}, Grid)
    self._board = empty_board()
    self._rand  = rand or math.random
    for r = 1, SIZE do
        for c = 1, SIZE do
            self._board[r][c] = cells[r][c]
        end
    end
    return self
end

local function slide_row_left(row)
    local packed = {}
    for c, v in ipairs(row) do
        if v ~= 0 then packed[#packed + 1] = {col = c, val = v} end
    end
    local result = {}
    local moves = {}
    local i = 1
    local score = 0
    local dest = 1
    while i <= #packed do
        if packed[i + 1] and packed[i].val == packed[i + 1].val then
            local val = packed[i].val * 2
            result[dest] = val
            score = score + val
            moves[#moves + 1] = {from_col = packed[i].col,     to_col = dest, value = packed[i].val,     merged = true}
            moves[#moves + 1] = {from_col = packed[i + 1].col, to_col = dest, value = packed[i + 1].val, merged = true}
            i = i + 2
        else
            result[dest] = packed[i].val
            moves[#moves + 1] = {from_col = packed[i].col, to_col = dest, value = packed[i].val}
            i = i + 1
        end
        dest = dest + 1
    end
    while #result < SIZE do result[#result + 1] = 0 end
    return result, score, moves
end

local function reverse(row)
    local r = {}
    for i = #row, 1, -1 do r[#r + 1] = row[i] end
    return r
end

local function col(board, c)
    local out = {}
    for r = 1, SIZE do out[r] = board[r][c] end
    return out
end

local function set_col(board, c, vals)
    for r = 1, SIZE do board[r][c] = vals[r] end
end

local function rows_equal(a, b)
    for i = 1, SIZE do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local DIRS = { left = true, right = true, up = true, down = true }

function Grid:move(direction)
    check.one_of(direction, DIRS, "direction")

    local moved = false
    local score_delta = 0
    local all_moves = {}

    if direction == "left" then
        for r = 1, SIZE do
            local old = {unpack(self._board[r])}
            local new_row, s, row_moves = slide_row_left(self._board[r])
            self._board[r] = new_row
            score_delta = score_delta + s
            if not rows_equal(old, new_row) then moved = true end
            for _, m in ipairs(row_moves) do
                all_moves[#all_moves + 1] = {from_row=r, from_col=m.from_col, to_row=r, to_col=m.to_col, value=m.value, merged=m.merged}
            end
        end
    elseif direction == "right" then
        for r = 1, SIZE do
            local old = {unpack(self._board[r])}
            local new_row, s, row_moves = slide_row_left(reverse(self._board[r]))
            new_row = reverse(new_row)
            self._board[r] = new_row
            score_delta = score_delta + s
            if not rows_equal(old, new_row) then moved = true end
            for _, m in ipairs(row_moves) do
                all_moves[#all_moves + 1] = {
                    from_row = r, from_col = SIZE + 1 - m.from_col,
                    to_row   = r, to_col   = SIZE + 1 - m.to_col,
                    value = m.value, merged = m.merged,
                }
            end
        end
    elseif direction == "up" then
        for c = 1, SIZE do
            local old = col(self._board, c)
            local new_col, s, row_moves = slide_row_left(old)
            set_col(self._board, c, new_col)
            score_delta = score_delta + s
            if not rows_equal(old, new_col) then moved = true end
            for _, m in ipairs(row_moves) do
                all_moves[#all_moves + 1] = {from_row=m.from_col, from_col=c, to_row=m.to_col, to_col=c, value=m.value, merged=m.merged}
            end
        end
    elseif direction == "down" then
        for c = 1, SIZE do
            local old = col(self._board, c)
            local new_col, s, row_moves = slide_row_left(reverse(old))
            new_col = reverse(new_col)
            set_col(self._board, c, new_col)
            score_delta = score_delta + s
            if not rows_equal(old, new_col) then moved = true end
            for _, m in ipairs(row_moves) do
                all_moves[#all_moves + 1] = {
                    from_row = SIZE + 1 - m.from_col, from_col = c,
                    to_row   = SIZE + 1 - m.to_col,   to_col   = c,
                    value = m.value, merged = m.merged,
                }
            end
        end
    end

    local win = false
    for r = 1, SIZE do
        for c = 1, SIZE do
            if self._board[r][c] >= config.WIN_TILE then win = true end
        end
    end

    local game_over = false
    if not win then
        game_over = self:_no_moves()
    end

    local filtered_moves = {}
    for _, m in ipairs(all_moves) do
        if m.merged or m.from_row ~= m.to_row or m.from_col ~= m.to_col then
            filtered_moves[#filtered_moves + 1] = m
        end
    end

    return {moved = moved, score_delta = score_delta, win = win, game_over = game_over, moves = filtered_moves}
end

function Grid:is_game_over()
    return self:_no_moves()
end

function Grid:_no_moves()
    for r = 1, SIZE do
        for c = 1, SIZE do
            if self._board[r][c] == 0 then return false end
            if c < SIZE and self._board[r][c] == self._board[r][c + 1] then return false end
            if r < SIZE and self._board[r][c] == self._board[r + 1][c] then return false end
        end
    end
    return true
end

function Grid:spawn_tile()
    assert(#empty_cells(self._board) > 0, "spawn_tile called on a full board")
    spawn_one(self._board, self._rand)
end

function Grid:get_cells()
    local copy = {}
    for r = 1, SIZE do
        copy[r] = {}
        for c = 1, SIZE do
            copy[r][c] = self._board[r][c]
        end
    end
    return copy
end

return M
