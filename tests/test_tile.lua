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

-- Tracer bullet: is_done() returns false before duration elapses, true after
test("tile.is_done() is false before duration elapses", function()
    local t = tile.new(2, 0, 0, 100, 0, 0.1)
    t:update(0.05)
    eq(t:is_done(), false, "should not be done at half duration")
end)

test("tile.is_done() is true when timer reaches duration", function()
    local t = tile.new(2, 0, 0, 100, 0, 0.1)
    t:update(0.1)
    eq(t:is_done(), true, "should be done at exactly duration")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
