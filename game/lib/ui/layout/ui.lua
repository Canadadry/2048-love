local compute = require("lib.ui.layout.compute")
local kind = require("lib.ui.layout.kind")

local function Tree(param)
    return function()
        return kind.Set({
            Node = {},
            StackSlice = nil,
            Commands = param.Commands or {},
            userdata = param.userdata or nil,
            measureContent = param.measureContent or function(userdata, painter)
                return { 0, 0 }
            end,
            wrapContent = param.wrapContent,
            -- function(userdata, painter, width)
            --     return height
            -- end

        }, "Tree")
    end
end



local function Node(tree, item, userdata, children_builder)
    kind.Check(tree, "Tree")
    kind.Check(item, "Frame")
    local id = #tree.Node + 1
    table.insert(tree.Node, item)
    if tree.StackSlice ~= nil then
        table.insert(tree.StackSlice, id)
    end
    if children_builder == nil then
        return
    end
    local previous_stack = tree.StackSlice
    tree.StackSlice = {}
    children_builder(tree, userdata)
    for _, value in ipairs(tree.StackSlice) do
        table.insert(tree.Node[id].children, value)
    end
    tree.StackSlice = previous_stack
end

local function Leaf(tree, item)
    kind.Check(tree, "Tree")
    return Node(tree, item, nil, nil)
end

local function DrawTree(tree)
    kind.Check(tree, "Tree")
    compute.FitSizeWidth(tree.Node, 1, nil, tree.userdata, tree.measureContent)
    compute.ShrinkSizeWidth(tree.Node, 1)
    compute.GrowSizeWidth(tree.Node, 1)
    if tree.wrapContent ~= nil then
        compute.Wrap(tree.Node, 1, tree.userdata, tree.wrapContent)
    end
    compute.FitSizeHeigh(tree.Node, 1, nil, tree.userdata, tree.measureContent)
    compute.ShrinkSizeHeight(tree.Node, 1)
    compute.GrowSizeHeigth(tree.Node, 1)
    compute.Position(tree.Node, 1, 0, 0)
    compute.DrawCommand(tree.Node, 1, tree.Commands)
end

return {
    Tree = Tree,
    Node = Node,
    Leaf = Leaf,
    DrawTree = DrawTree,
}
