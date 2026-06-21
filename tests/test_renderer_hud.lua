local hud = require("renderer.hud")

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

-- Tracer bullet: score is positioned just above the board, at the board's left edge
test("score_position sits above board_y by font_sz + 4", function()
    local x, y = hud.score_position(20, 100, 18)
    eq(x, 20, "x")
    eq(y, 100 - 18 - 4, "y")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
