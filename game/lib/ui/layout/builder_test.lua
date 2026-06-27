local ui      = require("lib.ui.layout.ui")
local builder = require("lib.ui.layout.builder")
local testing = require("lib.ui.layout.testing")
local T       = require("lib.t")

local TestTree = ui.Tree({
    measureContent = function(userdata, painter) return painter or { x = 0, y = 0 } end,
    wrapContent = function(userdata, painter, width)
        local painter = painter or { x = 0, y = 0 }
        local height = painter.x + painter.y - width
        return height < 0 and 0 or height
    end
})

local tests = {
    ["leaf, fixed size"] = {
        Gen = function(tree)
            builder.Build(tree, builder.Leaf("w-100 h-50"))
        end,
        Stack = {
            { x = 0, y = 0, w = 100, h = 50 }
        }
    },
    ["leaf, fixed position and size"] = {
        Gen = function(tree)
            builder.Build(tree, builder.Leaf("x-10 y-20 w-100 h-50"))
        end,
        Stack = {
            { x = 10, y = 20, w = 100, h = 50 }
        }
    },
    ["row with gap and padding, two fixed children"] = {
        Gen = function(tree)
            builder.Build(tree, builder.Node("row gap-10 p-10", nil, {
                builder.Leaf("w-50 h-100"),
                builder.Leaf("w-100 h-50"),
            }))
        end,
        Stack = {
            { x = 0,  y = 0,  w = 180, h = 120 },
            { x = 10, y = 10, w = 50,  h = 100 },
            { x = 70, y = 10, w = 100, h = 50 },
        }
    },
    ["col layout"] = {
        Gen = function(tree)
            builder.Build(tree, builder.Node("col", nil, {
                builder.Leaf("w-50 h-100"),
                builder.Leaf("w-100 h-50"),
            }))
        end,
        Stack = {
            { x = 0, y = 0,   w = 100, h = 150 },
            { x = 0, y = 0,   w = 50,  h = 100 },
            { x = 0, y = 100, w = 100, h = 50 },
        }
    },
    ["grow child fills remaining width"] = {
        Gen = function(tree)
            builder.Build(tree, builder.Node("row w-450", nil, {
                builder.Leaf("w-50 h-100"),
                builder.Leaf("grow"),
                builder.Leaf("w-100 h-50"),
            }))
        end,
        Stack = {
            { x = 0,   y = 0, w = 450, h = 100 },
            { x = 0,   y = 0, w = 50,  h = 100 },
            { x = 50,  y = 0, w = 300, h = 100 },
            { x = 350, y = 0, w = 100, h = 50 },
        }
    },
    ["centered alignment"] = {
        Gen = function(tree)
            builder.Build(tree, builder.Node("w-400 h-400 center", nil, {
                builder.Leaf("w-100 h-50"),
            }))
        end,
        Stack = {
            { x = 0,   y = 0,   w = 400, h = 400 },
            { x = 150, y = 175, w = 100, h = 50 },
        }
    },
    ["stack layout"] = {
        Gen = function(tree)
            builder.Build(tree, builder.Node("stack p-10 gap-10", nil, {
                builder.Leaf("w-100 h-50"),
                builder.Leaf("w-50 h-100"),
            }))
        end,
        Stack = {
            { x = 0,  y = 0,  w = 120, h = 120 },
            { x = 10, y = 10, w = 100, h = 50 },
            { x = 10, y = 10, w = 50,  h = 100 },
        }
    },
}

T.test("unknown class errors", function()
    local ok, err = pcall(builder.Frame, "not-a-real-class")
    if ok then error("expected an error, got none") end
    if not tostring(err):find("unknown ui class") then
        error("unexpected error: " .. tostring(err))
    end
end)

for name, tt in pairs(tests) do
    T.test(name, function()
        local tree = TestTree()
        tt.Gen(tree)
        ui.DrawTree(tree)
        for i, expected in ipairs(tt.Stack) do
            if not testing.match(expected, tree.Commands[i]) then
                error(string.format("[%d] exp -%s- got -%s-",
                    i,
                    testing.PrintValue(expected),
                    testing.PrintValue(tree.Commands[i])), 2)
            end
        end
    end)
end

T.report()
