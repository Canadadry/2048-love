local board = require("renderer.board")

local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("PASS " .. name)
        pass = pass + 1
    else
        print("FAIL " .. name)
        print("     " .. tostring(err))
        fail = fail + 1
    end
end

local function eq(a, b, msg)
    if a ~= b then
        error((msg or "eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

local function positive_finite(v, label)
    if type(v) ~= "number" or v <= 0 or v ~= v then
        error(label .. " must be a positive finite number, got " .. tostring(v), 2)
    end
end

-- Tracer bullet: metrics returns positive finite board/tile/pad dimensions
test("metrics returns positive finite dimensions", function()
    local board_px, tile_px, pad, board_x, board_y = board.metrics()
    positive_finite(board_px, "board_px")
    positive_finite(tile_px,  "tile_px")
    positive_finite(pad,      "pad")
    if board_x < 0 then error("board_x must be >= 0, got " .. board_x) end
    if board_y < 0 then error("board_y must be >= 0, got " .. board_y) end
end)

test("cell_to_px places cell (1,1) at board_x+pad, board_y+pad", function()
    local px, py = board.cell_to_px(1, 1, 100, 5, 20, 30)
    eq(px, 25, "px")
    eq(py, 35, "py")
end)

test("cell_to_px steps by tile_px per row/col", function()
    local px, py = board.cell_to_px(2, 3, 100, 5, 20, 30)
    eq(px, 20 + 2 * 100 + 5, "px")
    eq(py, 30 + 1 * 100 + 5, "py")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
