local unpack = table.unpack or unpack  -- Lua 5.1 (LuaJIT) vs 5.2+

local M = {}
local Grid = {}
Grid.__index = Grid

local SIZE = 4

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

local function spawn_one(board)
    local empty = empty_cells(board)
    if #empty == 0 then return end
    local pos = empty[math.random(#empty)]
    board[pos[1]][pos[2]] = math.random() < 0.9 and 2 or 4
end

function M.new()
    local self = setmetatable({}, Grid)
    self._board = empty_board()
    spawn_one(self._board)
    spawn_one(self._board)
    return self
end

function M.new_from(cells)
    local self = setmetatable({}, Grid)
    self._board = empty_board()
    for r = 1, SIZE do
        for c = 1, SIZE do
            self._board[r][c] = cells[r][c]
        end
    end
    return self
end

local function slide_row_left(row)
    local packed = {}
    for _, v in ipairs(row) do
        if v ~= 0 then packed[#packed + 1] = v end
    end
    local result = {}
    local i = 1
    local score = 0
    while i <= #packed do
        if packed[i + 1] and packed[i] == packed[i + 1] then
            local val = packed[i] * 2
            result[#result + 1] = val
            score = score + val
            i = i + 2
        else
            result[#result + 1] = packed[i]
            i = i + 1
        end
    end
    while #result < SIZE do result[#result + 1] = 0 end
    return result, score
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

function Grid:move(direction)
    local moved = false
    local score_delta = 0

    if direction == "left" then
        for r = 1, SIZE do
            local old = {unpack(self._board[r])}
            local new_row, s = slide_row_left(self._board[r])
            self._board[r] = new_row
            score_delta = score_delta + s
            if not rows_equal(old, new_row) then moved = true end
        end
    elseif direction == "right" then
        for r = 1, SIZE do
            local old = {unpack(self._board[r])}
            local new_row, s = slide_row_left(reverse(self._board[r]))
            new_row = reverse(new_row)
            self._board[r] = new_row
            score_delta = score_delta + s
            if not rows_equal(old, new_row) then moved = true end
        end
    elseif direction == "up" then
        for c = 1, SIZE do
            local old = col(self._board, c)
            local new_col, s = slide_row_left(old)
            set_col(self._board, c, new_col)
            score_delta = score_delta + s
            if not rows_equal(old, new_col) then moved = true end
        end
    elseif direction == "down" then
        for c = 1, SIZE do
            local old = col(self._board, c)
            local new_col, s = slide_row_left(reverse(old))
            new_col = reverse(new_col)
            set_col(self._board, c, new_col)
            score_delta = score_delta + s
            if not rows_equal(old, new_col) then moved = true end
        end
    end

    local win = false
    for r = 1, SIZE do
        for c = 1, SIZE do
            if self._board[r][c] == 2048 then win = true end
        end
    end

    local game_over = false
    if not win then
        game_over = self:_no_moves()
    end

    return {moved = moved, score_delta = score_delta, win = win, game_over = game_over}
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
    spawn_one(self._board)
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
