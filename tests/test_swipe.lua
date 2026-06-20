local swipe = require("swipe")

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

-- Tracer bullet
test("swipe right returns 'right'", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    local dir = s:touchreleased(1, 220, 105)
    eq(dir, "right")
end)

test("swipe left returns 'left'", function()
    local s = swipe.new(50)
    s:touchpressed(1, 200, 100)
    eq(s:touchreleased(1, 80, 105), "left")
end)

test("swipe down returns 'down'", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    eq(s:touchreleased(1, 105, 220), "down")
end)

test("swipe up returns 'up'", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 200)
    eq(s:touchreleased(1, 105, 80), "up")
end)

test("diagonal with |dx|>|dy| returns horizontal direction", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    eq(s:touchreleased(1, 200, 140), "right")
end)

test("diagonal with |dy|>|dx| returns vertical direction", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    eq(s:touchreleased(1, 140, 200), "down")
end)

test("swipe below threshold returns nil", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    eq(s:touchreleased(1, 130, 102), nil)
end)

test("touchmoved fires direction once threshold exceeded mid-drag", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    eq(s:touchmoved(1, 130, 102), nil)   -- below threshold
    eq(s:touchmoved(1, 165, 104), "right") -- threshold crossed
end)

test("touchreleased returns nil after touchmoved already consumed the gesture", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    s:touchmoved(1, 200, 105)   -- consumes
    eq(s:touchreleased(1, 210, 106), nil)
end)

test("touchmoved fires again from new origin after first fire (continuous drag)", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    eq(s:touchmoved(1, 200, 102), "right")  -- first fire, origin resets to (200,102)
    eq(s:touchmoved(1, 220, 102), nil)       -- below threshold from new origin
    eq(s:touchmoved(1, 100, 102), "left")   -- second fire from new origin
end)

test("touchreleased still fires when touchmoved never crossed threshold", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    s:touchmoved(1, 120, 102)   -- below threshold, does not consume
    eq(s:touchreleased(1, 220, 105), "right")
end)

test("two independent touch ids resolved in sequence", function()
    local s = swipe.new(50)
    s:touchpressed(1, 100, 100)
    s:touchpressed(2, 200, 200)
    eq(s:touchreleased(1, 220, 105), "right")
    eq(s:touchreleased(2, 205, 80),  "up")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
