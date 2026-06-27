love = {
    graphics   = {
        getDimensions = function() return 600, 600 end,
        newFont = function(size)
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 18 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
    },
    filesystem = {
        getDirectoryItems = function(_) return {} end,
        read              = function(_) return nil end,
        write             = function(_, _) return true end,
    },
}
local menu = require("menu")

local T    = require("lib.t")
local test = T.test

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

local function interactive_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and (cmd.painter.kind == "Group" or cmd.painter.kind == "Interactive") then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

-- ── Generic builder, Cycle 1: button-style items, tap routes to on_tap(i) ────

test("menu_hit_test (button style) routes taps to on_tap(i), and a miss fires none", function()
    local spec = {
        title      = "Title",
        bg_color   = { 250, 247, 240, 255 },
        item_style = "button",
        items      = {
            { label = "One" },
            { label = "Two" },
            { label = "Three" },
        },
    }
    local centers = button_centers(menu.menu_tree(spec, 0, nil))
    if #centers ~= 3 then error("expected 3 buttons, got " .. #centers) end

    local tapped
    local on_tap = function(i) tapped = i end

    tapped = nil
    menu.menu_hit_test(spec, 0, on_tap, centers[1].x, centers[1].y)
    if tapped ~= 1 then error("expected 1, got " .. tostring(tapped)) end

    tapped = nil
    menu.menu_hit_test(spec, 0, on_tap, centers[3].x, centers[3].y)
    if tapped ~= 3 then error("expected 3, got " .. tostring(tapped)) end

    tapped = nil
    menu.menu_hit_test(spec, 0, on_tap, 5, 5)
    if tapped ~= nil then error("expected no callback to fire on a miss, got " .. tostring(tapped)) end
end)

-- ── Generic builder, Cycle 2: row-style items, value rows + decorative hint ──

test("menu_hit_test (row style) routes taps to value rows but skips a non-focusable hint", function()
    local spec = {
        title      = "Options",
        bg_color   = { 250, 247, 240, 255 },
        item_style = "row",
        items      = {
            { label = "Win Tile", value = 2048 },
            { label = "Hint text", focusable = false },
            { label = "Back" },
        },
    }
    local centers = interactive_centers(menu.menu_tree(spec, 0, nil))
    if #centers ~= 2 then error("expected 2 interactive rows (hint excluded), got " .. #centers) end

    local tapped
    local on_tap = function(i) tapped = i end

    tapped = nil
    menu.menu_hit_test(spec, 0, on_tap, centers[1].x, centers[1].y)
    if tapped ~= 1 then error("expected row 1 (Win Tile), got " .. tostring(tapped)) end

    tapped = nil
    menu.menu_hit_test(spec, 0, on_tap, centers[2].x, centers[2].y)
    if tapped ~= 3 then error("expected row 3 (Back), got " .. tostring(tapped)) end
end)

-- ── Generic builder, Cycle 3: btn_w_ratio overrides the default button width ─

test("btn_w_ratio narrows button-style items relative to the default ratio", function()
    local function spec_with(ratio)
        return {
            bg_color   = { 250, 247, 240, 255 },
            item_style = "button",
            btn_w_ratio = ratio,
            items      = { { label = "Solo" } },
        }
    end
    local function button_width(tree)
        for _, cmd in ipairs(tree.Commands) do
            if cmd.painter and cmd.painter.kind == "Group" then return cmd.w end
        end
    end
    local default_w = button_width(menu.menu_tree(spec_with(0.5), 0, nil))
    local narrow_w   = button_width(menu.menu_tree(spec_with(0.4), 0, nil))
    if not (narrow_w < default_w) then
        error("expected a 0.4 ratio button (" .. tostring(narrow_w) .. ") to be narrower than a 0.5 ratio button (" .. tostring(default_w) .. ")")
    end
end)

T.report()
