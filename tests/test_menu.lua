love = {
    graphics   = { getDimensions = function() return 600, 600 end },
    filesystem = {
        getDirectoryItems = function(_) return {} end,
        read              = function(_) return nil end,
        write             = function(_, _) return true end,
    },
}
local menu = require("menu")

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

local function positive_finite(v, label)
    if type(v) ~= "number" or v <= 0 or v ~= v then
        error(label .. " must be a positive finite number, got " .. tostring(v), 2)
    end
end

test("pause_button_bounds returns 4 buttons with positive finite dimensions", function()
    local btns = menu.pause_button_bounds()
    if #btns ~= 4 then error("expected 4 buttons, got " .. #btns) end
    for i, b in ipairs(btns) do
        local pfx = "button[" .. i .. "]."
        positive_finite(b.x, pfx .. "x")
        positive_finite(b.y, pfx .. "y")
        positive_finite(b.w, pfx .. "w")
        positive_finite(b.h, pfx .. "h")
    end
end)

test("pause_button_bounds button labels are Resume, New Game, Main Menu, Quit", function()
    local btns = menu.pause_button_bounds()
    if btns[1].label ~= "Resume"    then error("button 1 label: " .. tostring(btns[1].label)) end
    if btns[2].label ~= "New Game"  then error("button 2 label: " .. tostring(btns[2].label)) end
    if btns[3].label ~= "Main Menu" then error("button 3 label: " .. tostring(btns[3].label)) end
    if btns[4].label ~= "Quit"      then error("button 4 label: " .. tostring(btns[4].label)) end
end)

test("pause_icon_bounds returns a single rect with positive finite dimensions", function()
    local b = menu.pause_icon_bounds()
    positive_finite(b.x, "x")
    positive_finite(b.y, "y")
    positive_finite(b.w, "w")
    positive_finite(b.h, "h")
end)

test("pause_icon_bounds is at least 44x44 for touch targets", function()
    local b = menu.pause_icon_bounds()
    if b.w < 44 then error("width " .. b.w .. " < 44") end
    if b.h < 44 then error("height " .. b.h .. " < 44") end
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
