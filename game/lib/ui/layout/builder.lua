local frame = require("lib.ui.layout.frame")
local ui = require("lib.ui.layout.ui")
local kind = require("lib.ui.layout.kind")

-- Builds Frame trees from a single space-separated class string instead of
-- nested frame.Frame{} tables, e.g. "row gap-8 p-16 grow".
-- Mirrors https://github.com/Canadadry/zui/blob/master/src/builder.zig
-- "x-N"/"y-N" are a Lua-only addition: frame.Frame has a first-class `pos`
-- field (for anchoring a root frame on screen) that the zig Node doesn't.

local function numOf(tok, prefix)
    if tok:sub(1, #prefix) ~= prefix then
        return nil
    end
    return tonumber(tok:sub(#prefix + 1))
end

local function newState()
    return {
        layout = nil,
        size_x = { kind = "Fit", min = 0, max = 0, value = 0 },
        size_y = { kind = "Fit", min = 0, max = 0, value = 0 },
        align_x = nil,
        align_y = nil,
        margin = 0,
        padding = { left = 0, right = 0, top = 0, bottom = 0 },
        pos_x = 0,
        pos_y = 0,
    }
end

local function applyToken(tok, state)
    if tok == "row" then state.layout = frame.Layout.Horizontal(); return true end
    if tok == "col" then state.layout = frame.Layout.Vertical(); return true end
    if tok == "stack" then state.layout = frame.Layout.Stack(); return true end

    if tok == "grow" then state.size_x.kind = "Grow"; state.size_y.kind = "Grow"; return true end
    if tok == "grow-x" then state.size_x.kind = "Grow"; return true end
    if tok == "grow-y" then state.size_y.kind = "Grow"; return true end

    if tok == "center" then state.align_x = frame.Align.Middle(); state.align_y = frame.Align.Middle(); return true end
    if tok == "ax-start" then state.align_x = frame.Align.Begin(); return true end
    if tok == "ax-center" then state.align_x = frame.Align.Middle(); return true end
    if tok == "ax-end" then state.align_x = frame.Align.End(); return true end
    if tok == "ay-start" then state.align_y = frame.Align.Begin(); return true end
    if tok == "ay-center" then state.align_y = frame.Align.Middle(); return true end
    if tok == "ay-end" then state.align_y = frame.Align.End(); return true end

    if tok == "w-fit" then state.size_x.kind = "Fit"; return true end
    if tok == "w-grow" then state.size_x.kind = "Grow"; return true end
    local v = numOf(tok, "min-w-")
    if v then state.size_x.min = v; return true end
    v = numOf(tok, "max-w-")
    if v then state.size_x.max = v; return true end
    v = numOf(tok, "w-")
    if v then state.size_x.kind = "Fixed"; state.size_x.value = v; return true end

    if tok == "h-fit" then state.size_y.kind = "Fit"; return true end
    if tok == "h-grow" then state.size_y.kind = "Grow"; return true end
    v = numOf(tok, "min-h-")
    if v then state.size_y.min = v; return true end
    v = numOf(tok, "max-h-")
    if v then state.size_y.max = v; return true end
    v = numOf(tok, "h-")
    if v then state.size_y.kind = "Fixed"; state.size_y.value = v; return true end

    v = numOf(tok, "px-")
    if v then state.padding.left = v; state.padding.right = v; return true end
    v = numOf(tok, "py-")
    if v then state.padding.top = v; state.padding.bottom = v; return true end
    v = numOf(tok, "pl-")
    if v then state.padding.left = v; return true end
    v = numOf(tok, "pr-")
    if v then state.padding.right = v; return true end
    v = numOf(tok, "pt-")
    if v then state.padding.top = v; return true end
    v = numOf(tok, "pb-")
    if v then state.padding.bottom = v; return true end
    v = numOf(tok, "p-")
    if v then state.padding = { left = v, right = v, top = v, bottom = v }; return true end

    v = numOf(tok, "gap-")
    if v then state.margin = v; return true end

    v = numOf(tok, "x-")
    if v then state.pos_x = v; return true end
    v = numOf(tok, "y-")
    if v then state.pos_y = v; return true end

    return false
end

local function buildSize(spec)
    if spec.kind == "Fixed" then
        return frame.Size.Fixed(spec.value)
    elseif spec.kind == "Grow" then
        return frame.Size.Grow(spec.min, spec.max)
    else
        return frame.Size.Fit(spec.min, spec.max)
    end
end

local function ParseFrame(classes, painter)
    local state = newState()
    for tok in (classes or ""):gmatch("%S+") do
        if not applyToken(tok, state) then
            error("unknown ui class: '" .. tok .. "'")
        end
    end
    return frame.Frame {
        pos_x = state.pos_x,
        pos_y = state.pos_y,
        size_x = buildSize(state.size_x),
        size_y = buildSize(state.size_y),
        layout = state.layout,
        align_x = state.align_x,
        align_y = state.align_y,
        margin = state.margin,
        padding = kind.Set({
            left = state.padding.left,
            right = state.padding.right,
            top = state.padding.top,
            bottom = state.padding.bottom,
        }, "Padding"),
        painter = painter,
    }
end

local function Node(classes, painter, children)
    return { classes = classes, painter = painter, children = children or {} }
end

local function Leaf(classes, painter)
    return Node(classes, painter, {})
end

local function Build(tree, spec)
    local item = ParseFrame(spec.classes, spec.painter)
    if #spec.children == 0 then
        ui.Leaf(tree, item)
        return
    end
    ui.Node(tree, item, nil, function(tree)
        for _, child in ipairs(spec.children) do
            Build(tree, child)
        end
    end)
end

return {
    Frame = ParseFrame,
    Node = Node,
    Leaf = Leaf,
    Build = Build,
}
