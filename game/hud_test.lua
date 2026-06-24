love = {
    graphics = {
        getDimensions = function() return 600, 600 end,
        newFont = function(size)
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 18 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
        setColor  = function(...) end,
        setFont   = function(...) end,
        rectangle = function(...) end,
        printf    = function(...) end,
    },
}

local hud   = require("hud")
local board = require("board")

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

local function find_kind(tree, kind)
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == kind then
            return cmd
        end
    end
    return nil
end

-- Tracer bullet: the icon anchors to the board's top-right corner, inset by `pad`
test("hud_tree anchors the icon's right edge to board's right edge minus pad", function()
    local tree = hud.hud_tree(0, {})
    local board_px, _, pad, board_x = board.metrics()
    local icon = find_kind(tree, "Group")
    if not icon then error("expected an icon Group command") end
    eq(icon.x + icon.w, board_x + board_px - pad, "icon right edge")
end)

test("hud_tree centers the icon and score vertically against each other", function()
    local tree = hud.hud_tree(0, {})
    local icon  = find_kind(tree, "Group")
    local score = find_kind(tree, "Text")
    eq(icon.y + icon.h / 2, score.y + score.h / 2, "vertical center")
end)

test("hud_tree icon is at least 44x44 for touch targets", function()
    local tree = hud.hud_tree(0, {})
    local icon = find_kind(tree, "Group")
    if icon.w < 44 then error("width " .. icon.w .. " < 44") end
    if icon.h < 44 then error("height " .. icon.h .. " < 44") end
end)

test("hit_test fires on_pause_tap on a hit inside the icon, and nothing on a miss", function()
    local tree = hud.hud_tree(0, {})
    local icon = find_kind(tree, "Group")
    local cx, cy = icon.x + icon.w / 2, icon.y + icon.h / 2

    local fired = false
    hud.hit_test(0, { on_pause_tap = function() fired = true end }, cx, cy)
    eq(fired, true, "expected on_pause_tap to fire on a hit")

    fired = false
    hud.hit_test(0, { on_pause_tap = function() fired = true end }, 0, 0)
    eq(fired, false, "expected no callback to fire on a miss")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
