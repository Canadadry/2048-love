local optionsmodel = require("optionsmodel")

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

local function two_rows()
    return optionsmodel.new({
        { label = "Win Tile", values = { 32, 2048 } },
        { label = "Theme",    values = { "none", "jurassic-park", "ocean" } },
    })
end

test("down() moves focus to the next row", function()
    local m = two_rows()
    m:down()
    eq(m:focused_row(), 2, "focused_row after down()")
end)

test("down() wraps from the last row back to the first", function()
    local m = two_rows()
    m:down()
    m:down()
    eq(m:focused_row(), 1, "focused_row after wrapping down()")
end)

test("up() moves focus to the previous row", function()
    local m = two_rows()
    m:down()
    m:up()
    eq(m:focused_row(), 1, "focused_row after down() then up()")
end)

test("up() wraps from the first row to the last", function()
    local m = two_rows()
    m:up()
    eq(m:focused_row(), 2, "focused_row after wrapping up()")
end)

test("row_value() returns each row's starting value", function()
    local m = two_rows()
    eq(m:row_value(1), 32, "row 1 starting value")
    eq(m:row_value(2), "none", "row 2 starting value")
end)

test("right() cycles the focused row's value forward", function()
    local m = two_rows()
    m:right()
    eq(m:row_value(1), 2048, "row 1 value after right()")
end)

test("right() wraps from the last value back to the first", function()
    local m = two_rows()
    m:right()
    m:right()
    eq(m:row_value(1), 32, "row 1 value after wrapping right()")
end)

test("left() cycles the focused row's value backward", function()
    local m = two_rows()
    m:down()
    m:right()
    m:left()
    eq(m:row_value(2), "none", "row 2 value after right() then left()")
end)

test("left() wraps from the first value to the last", function()
    local m = two_rows()
    m:left()
    eq(m:row_value(1), 2048, "row 1 value after wrapping left()")
end)

test("right() on the focused row leaves other rows' values unchanged", function()
    local m = two_rows()
    m:down()
    m:right()
    eq(m:row_value(1), 32, "row 1 value should be untouched while row 2 is focused")
end)

test("up()/down() never change any row's value", function()
    local m = two_rows()
    m:down()
    m:up()
    eq(m:row_value(1), 32, "row 1 value unchanged by focus movement")
    eq(m:row_value(2), "none", "row 2 value unchanged by focus movement")
end)

test("left()/right() never change which row has focus", function()
    local m = two_rows()
    m:right()
    m:left()
    eq(m:focused_row(), 1, "focused_row unchanged by value cycling")
end)

test("new() rejects an empty row list", function()
    local ok = pcall(optionsmodel.new, {})
    eq(ok, false, "new() should reject an empty row list")
end)

test("new() rejects a row with an empty values list", function()
    local ok = pcall(optionsmodel.new, { { label = "Empty", values = {} } })
    eq(ok, false, "new() should reject a row with no values")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
