local grid = require("grid")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

-- Tracer bullet: new grid starts with exactly 2 tiles
test("new() starts with exactly 2 tiles on the board", function()
    local g = grid.new()
    local cells = g:get_cells()
    local count = 0
    for r = 1, 4 do
        for c = 1, 4 do
            if cells[r][c] ~= 0 then count = count + 1 end
        end
    end
    eq(count, 2)
end)

-- Tiles slide toward the leading edge on move
test("move left slides tiles to the left edge", function()
    local g = grid.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    g:move("left")
    local cells = g:get_cells()
    eq(cells[1][1], 2)
    eq(cells[1][2], 4)
    eq(cells[1][3], 0)
    eq(cells[1][4], 0)
end)

-- Equal tiles that collide merge into double the value
test("move left merges equal adjacent tiles", function()
    local g = grid.new_from({
        {2, 2, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    g:move("left")
    local cells = g:get_cells()
    eq(cells[1][1], 4)
    eq(cells[1][2], 0)
end)

-- Merge returns the sum of all merged tile values as score_delta
test("move left returns correct score_delta for all merges", function()
    local g = grid.new_from({
        {2, 2, 4, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local result = g:move("left")
    eq(result.score_delta, 12)  -- 4 + 8
end)

-- A tile produced by a merge cannot merge again in the same move
test("move left does not merge a tile twice in one move", function()
    local g = grid.new_from({
        {2, 2, 2, 2},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    g:move("left")
    local cells = g:get_cells()
    eq(cells[1][1], 4)
    eq(cells[1][2], 4)
    eq(cells[1][3], 0)
    eq(cells[1][4], 0)
end)

-- move() returns moved=false when the board state does not change
test("move returns moved=false when no tile changes position", function()
    local g = grid.new_from({
        {2, 4, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local result = g:move("left")
    eq(result.moved, false)
end)

-- All four directions slide and merge correctly
test("move right slides and merges toward the right edge", function()
    local g = grid.new_from({
        {2, 0, 2, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    g:move("right")
    local cells = g:get_cells()
    eq(cells[1][4], 4)
    eq(cells[1][3], 4)
    eq(cells[1][2], 0)
    eq(cells[1][1], 0)
end)

test("move up slides and merges toward the top edge", function()
    local g = grid.new_from({
        {0, 0, 0, 0},
        {2, 0, 0, 0},
        {0, 0, 0, 0},
        {2, 0, 0, 0},
    })
    g:move("up")
    local cells = g:get_cells()
    eq(cells[1][1], 4)
    eq(cells[2][1], 0)
end)

test("move down slides and merges toward the bottom edge", function()
    local g = grid.new_from({
        {2, 0, 0, 0},
        {0, 0, 0, 0},
        {2, 0, 0, 0},
        {0, 0, 0, 0},
    })
    g:move("down")
    local cells = g:get_cells()
    eq(cells[4][1], 4)
    eq(cells[3][1], 0)
end)

-- spawn_tile places a new 2 or 4 in a previously empty cell
test("spawn_tile adds exactly one tile (value 2 or 4) to an empty cell", function()
    local g = grid.new_from({
        {2, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    g:spawn_tile()
    local cells = g:get_cells()
    local count = 0
    for r = 1, 4 do
        for c = 1, 4 do
            if cells[r][c] ~= 0 then
                eq(cells[r][c] == 2 or cells[r][c] == 4, true, "tile value must be 2 or 4")
                count = count + 1
            end
        end
    end
    eq(count, 2)  -- was 1, now 2 after spawn
end)

-- new_from() accepts an injectable rand function, used deterministically by spawn_tile
test("spawn_tile uses the injected rand function for deterministic spawns", function()
    local function rand(n)
        if n then return 1 end  -- always pick the first empty cell
        return 0                -- always spawn a 2 (rand() < 0.9)
    end
    local g = grid.new_from({
        {2, 2, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    }, rand)
    g:spawn_tile()
    local cells = g:get_cells()
    eq(cells[1][3], 2, "spawn lands on the first empty cell with value 2")
end)

-- game_over=true when the board is full with no possible merges in any direction
test("move returns game_over=true when no legal move exists in any direction", function()
    -- Fully locked checkerboard: no empty cells, no adjacent equal tiles.
    -- No direction can change anything; game_over must be true.
    local g = grid.new_from({
        {2, 4, 2, 4},
        {4, 2, 4, 2},
        {2, 4, 2, 4},
        {4, 2, 4, 2},
    })
    local result = g:move("left")
    eq(result.moved,     false)
    eq(result.game_over, true)
end)

-- win=true when a merge produces a 2048 tile
test("move returns win=true when a 2048 tile is produced", function()
    local g = grid.new_from({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    local result = g:move("left")
    eq(result.win, true)
    local cells = g:get_cells()
    eq(cells[1][1], 2048)
end)

-- move() must not call table.unpack directly (nil in LuaJIT / Lua 5.1)
test("move() works when table.unpack is nil (LuaJIT compatibility)", function()
    local saved = table.unpack
    table.unpack = nil
    local g = grid.new_from({{0,2,0,4},{0,0,0,0},{0,0,0,0},{0,0,0,0}})
    local ok, err = pcall(function() g:move("left") end)
    table.unpack = saved
    if not ok then error(err, 2) end
end)

-- move() returns a moves list (slide animation descriptors)

test("move() descriptors carry correct from/to positions for a simple left slide", function()
    local g = grid.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local result = g:move("left")
    local moves = result.moves
    eq(#moves, 2, "two tiles moved")
    -- first descriptor: value=2 came from col 2, went to col 1
    local m1 = moves[1]
    eq(m1.from_row, 1);  eq(m1.from_col, 2)
    eq(m1.to_row,   1);  eq(m1.to_col,   1)
    eq(m1.value,    2)
    -- second descriptor: value=4 came from col 4, went to col 2
    local m2 = moves[2]
    eq(m2.from_row, 1);  eq(m2.from_col, 4)
    eq(m2.to_row,   1);  eq(m2.to_col,   2)
    eq(m2.value,    4)
end)

test("move() merge produces two descriptors both pointing to the destination cell", function()
    local g = grid.new_from({
        {2, 2, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local result = g:move("left")
    local moves = result.moves
    eq(#moves, 2, "two source tiles for one merge")
    eq(moves[1].to_col, 1, "first tile goes to col 1")
    eq(moves[2].to_col, 1, "second tile goes to col 1")
    eq(moves[1].from_col, 1, "first tile was at col 1")
    eq(moves[2].from_col, 2, "second tile was at col 2")
    eq(moves[1].value, 2, "first tile value")
    eq(moves[2].value, 2, "second tile value")
end)

test("move() with no board change returns an empty moves list", function()
    local g = grid.new_from({
        {2, 4, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local result = g:move("left")
    eq(result.moved, false)
    eq(#result.moves, 0, "no moves when board unchanged")
end)

test("move() returns a non-empty moves list when tiles slide", function()
    local g = grid.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local result = g:move("left")
    eq(type(result.moves), "table", "moves should be a table")
    eq(#result.moves > 0, true, "moves should be non-empty")
end)

T.report()
