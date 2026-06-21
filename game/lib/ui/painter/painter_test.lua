-- Run from: cd game && lua lib/ui/painter/painter_test.lua
love = {
    graphics = {
        getDimensions = function() return 600, 600 end,
        getFont = function()
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 14 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
        setColor  = function(...) end,
        rectangle = function(...) end,
        draw      = function(...) end,
        printf    = function(...) end,
    }
}

local painter = require("lib.ui.painter.painter")
local ui = require("lib.ui.layout.ui")
local frame = require("lib.ui.layout.frame")

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

test("Interactive measures as zero size", function()
    local p = painter.Interactive { onTap = function() end }
    local m = painter.Measure(nil, p)
    eq(m.x, 0, "m.x")
    eq(m.y, 0, "m.y")
end)

test("Interactive wraps to zero height", function()
    local p = painter.Interactive { onTap = function() end }
    eq(painter.Wrap(nil, p, 100), 0, "wrap height")
end)

test("Group constructor errors immediately on a non-Painter entry", function()
    local ok, err = pcall(painter.Group, { painters = { { kind = "NotAPainter" } } })
    if ok then error("expected construction to fail for a non-Painter entry") end
    if not tostring(err):find("Painter") then
        error("expected error to mention Painter, got: " .. tostring(err))
    end
end)

test("Group Draw runs every child painter against the same box", function()
    local rect_draws = 0
    local real_rectangle = love.graphics.rectangle
    love.graphics.rectangle = function(...) rect_draws = rect_draws + 1 end
    local tapped = false
    local p = painter.Group {
        painters = {
            painter.Rectangle {},
            painter.Interactive { onTap = function() tapped = true end },
        }
    }
    painter.Draw({ x = 0, y = 0, w = 10, h = 10 }, p)
    love.graphics.rectangle = real_rectangle
    eq(rect_draws, 1, "rectangle draw count")
    eq(tapped, false, "Interactive.Draw must stay a no-op")
end)

test("Group Measure returns the max across children, recursing into nested Groups", function()
    local p = painter.Group {
        painters = {
            painter.Image { src = { getPixelWidth = function() return 5 end, getPixelHeight = function() return 40 end } },
            painter.Group {
                painters = {
                    painter.Image { src = { getPixelWidth = function() return 30 end, getPixelHeight = function() return 5 end } },
                }
            },
        }
    }
    local m = painter.Measure(nil, p)
    eq(m.x, 30, "m.x should be the max width across all nested children")
    eq(m.y, 40, "m.y should be the max height across all nested children")
end)

test("Group Wrap returns the max across children, recursing into nested Groups", function()
    local p = painter.Group {
        painters = {
            painter.Image { src = { getPixelWidth = function() return 10 end, getPixelHeight = function() return 20 end } },
            painter.Group {
                painters = {
                    painter.Image { src = { getPixelWidth = function() return 10 end, getPixelHeight = function() return 50 end } },
                }
            },
        }
    }
    eq(painter.Wrap(nil, p, 10), 50, "wrap should take the max wrapped height across all nested children")
end)

test("empty Group behaves like a nil painter: zero size, no-op Draw", function()
    local p = painter.Group { painters = {} }
    local m = painter.Measure(nil, p)
    eq(m.x, 0, "m.x")
    eq(m.y, 0, "m.y")
    eq(painter.Wrap(nil, p, 100), 0, "wrap height")
    painter.Draw({ x = 0, y = 0, w = 10, h = 10 }, p) -- must not error
end)

test("ui.HitTest returns nil on a clean miss", function()
    local tree = painter.Tree()
    ui.Leaf(tree, frame.Frame { pos = frame.Pos(0, 0), size = frame.Size(50, 50) })
    ui.DrawTree(tree)
    local cb = ui.HitTest(tree, 200, 200)
    eq(cb, nil, "callback")
end)

test("ui.HitTest hits a node whose painter is a plain Interactive", function()
    local hit = false
    local tree = painter.Tree()
    ui.Leaf(tree, frame.Frame {
        pos = frame.Pos(0, 0),
        size = frame.Size(50, 50),
        painter = painter.Interactive { onTap = function() hit = true end },
    })
    ui.DrawTree(tree)
    local cb = ui.HitTest(tree, 25, 25)
    if cb == nil then error("expected a callback, got nil") end
    cb()
    eq(hit, true, "hit")
end)

test("ui.HitTest hits a node whose painter is a Group{Rectangle, Interactive}", function()
    local hit = false
    local tree = painter.Tree()
    ui.Leaf(tree, frame.Frame {
        pos = frame.Pos(0, 0),
        size = frame.Size(50, 50),
        painter = painter.Group {
            painters = {
                painter.Rectangle {},
                painter.Interactive { onTap = function() hit = true end },
            }
        },
    })
    ui.DrawTree(tree)
    local cb = ui.HitTest(tree, 25, 25)
    if cb == nil then error("expected a callback, got nil") end
    cb()
    eq(hit, true, "hit")
end)

test("ui.HitTest: back-to-front precedence when boxes overlap", function()
    local tree = painter.Tree()
    ui.Node(tree, frame.Frame { layout = frame.Layout.Stack(), size = frame.Size(50, 50) }, nil, function(tree)
        ui.Leaf(tree, frame.Frame {
            size = frame.Size(50, 50),
            painter = painter.Interactive { onTap = function() return "bottom" end },
        })
        ui.Leaf(tree, frame.Frame {
            size = frame.Size(50, 50),
            painter = painter.Interactive { onTap = function() return "top" end },
        })
    end)
    ui.DrawTree(tree)
    local cb = ui.HitTest(tree, 25, 25)
    eq(cb(), "top", "the later/topmost node should win")
end)

test("ui.HitTest: Group with two Interactives returns the last one's callback", function()
    local tree = painter.Tree()
    ui.Leaf(tree, frame.Frame {
        pos = frame.Pos(0, 0),
        size = frame.Size(50, 50),
        painter = painter.Group {
            painters = {
                painter.Interactive { onTap = function() return "first" end },
                painter.Interactive { onTap = function() return "last" end },
            }
        },
    })
    ui.DrawTree(tree)
    local cb = ui.HitTest(tree, 25, 25)
    eq(cb(), "last", "the last/topmost-within-group Interactive should win")
end)

test("ui.HitTest resolves through a nested Group{ Group{ Interactive } }", function()
    local tree = painter.Tree()
    ui.Leaf(tree, frame.Frame {
        pos = frame.Pos(0, 0),
        size = frame.Size(50, 50),
        painter = painter.Group {
            painters = {
                painter.Group {
                    painters = { painter.Interactive { onTap = function() return "nested" end } },
                },
            }
        },
    })
    ui.DrawTree(tree)
    local cb = ui.HitTest(tree, 25, 25)
    eq(cb(), "nested", "nested Group should resolve correctly")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
