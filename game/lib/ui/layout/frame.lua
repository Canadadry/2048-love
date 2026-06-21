local kind = require("lib.ui.layout.kind")

local function Fixed(v)
    return kind.Set({
        type = "Fixed",
        value = v or 0,
    }, "Size")
end

local function Fit(min, max)
    return kind.Set({
        type = "Fit",
        min = min or 0,
        max = max or 0,
    }, "Size")
end

local function Grow(min, max)
    return kind.Set({
        type = "Grow",
        min = min or 0,
        max = max or 0,
    }, "Size")
end

local function Horizontal()
    return kind.Set({ type = "Horizontal" }, "Layout")
end

local function Vertical()
    return kind.Set({ type = "Vertical" }, "Layout")
end

local function Stack()
    return kind.Set({ type = "Stack" }, "Layout")
end

local function Begin()
    return kind.Set({ type = "Begin" }, "Align")
end

local function Middle()
    return kind.Set({ type = "Middle" }, "Align")
end

local function End()
    return kind.Set({ type = "End" }, "Align")
end

local function Padding(left, right, top, bottom)
    return kind.Set({
        left = left,
        right = right,
        top = top,
        bottom = bottom,
    }, "Padding")
end

local function PaddingAll(v) return Padding(v, v, v, v) end
local function PaddingHV(h, v) return Padding(h, h, v, v) end
local function PaddingH(v) return PaddingHV(v, 0) end
local function PaddingV(v) return PaddingHV(0, v) end

local function Box(x, y, w, h)
    return {
        x = x or 0,
        y = y or 0,
        w = w or 0,
        h = h or 0,
    }
end


local function Pos(x, y)
    return kind.Set({ x = x or 0, y = y or 0 }, "Position")
end

local function Size(x, y)
    if type(x) == "number" then
        x = Fixed(x)
    end
    if type(y) == "number" then
        y = Fixed(y)
    end
    return kind.Set({ x = x or Fit(), y = y or Fit() }, "Size2")
end

local function Frame(param)
    return kind.Set({
        pos = kind.Check(param.pos, "Position") or {
            x = param.pos_x or 0,
            y = param.pos_y or 0,
        },
        size = kind.Check(param.size, "Size2") or {
            x = kind.Check(param.size_x, "Size") or Fit(),
            y = kind.Check(param.size_y, "Size") or Fit(),
        },
        layout = kind.Check(param.layout, "Layout") or Horizontal(),
        align = kind.Check(param.align, "Align2") or {
            x = kind.Check(param.align_x, "Align") or Begin(),
            y = kind.Check(param.align_y, "Align") or Begin(),
        },
        margin = param.margin or 0,
        padding = kind.Check(param.padding, "Padding") or PaddingAll(0),
        computed_box = Box(),
        children = {},
        painter = param.painter or nil,
    }, "Frame")
end

local out = {
    Frame = Frame,
    Padding = {
        All = PaddingAll,
        HV = PaddingHV,
        H = PaddingH,
        V = PaddingV,
    },
    Size = {
        Fixed = Fixed,
        Fit = Fit,
        Grow = Grow,
    },
    Layout = {
        Horizontal = Horizontal,
        Vertical = Vertical,
        Stack = Stack,
    },
    Align = {
        Begin = Begin,
        Middle = Middle,
        End = End,
    },
    Pos = Pos,
}

setmetatable(out.Size, {
    __call = function(self, x, y) return Size(x, y) end,
})
setmetatable(out.Align, {
    __call = function(self, x, y) return kind.Set({ x = x or Begin(), y = y or Begin(), }, "Align2") end,
})
return out
