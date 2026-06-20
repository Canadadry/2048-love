local tile = require("tile")

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

test("tile.is_done() is false before duration elapses", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(0.05)
    eq(t:is_done(), false, "should not be done at half duration")
end)

test("tile.is_done() is true when timer reaches duration", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(0.1)
    eq(t:is_done(), true, "should be done at exactly duration")
end)

test("tile.progress() is 0.5 at half duration", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(0.05)
    eq(t:progress(), 0.5, "progress at half duration")
end)

test("tile.progress() clamps to 1 past duration", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(9999)
    eq(t:progress(), 1, "progress clamps at 1")
end)

test("tile.finish() makes is_done() return true immediately", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:finish()
    eq(t:is_done(), true, "finish() should mark tile as done")
end)

test("tile.new() stores row/col fields correctly", function()
    local t = tile.new(8, 2, 3, 4, 1, 0.1)
    eq(t.value,    8, "value")
    eq(t.from_row, 2, "from_row")
    eq(t.from_col, 3, "from_col")
    eq(t.to_row,   4, "to_row")
    eq(t.to_col,   1, "to_col")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
