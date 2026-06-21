local internals = require("lib.ui.layout.compute_internals")

local function FitSizeWidth(nodes, index, parent_id, userdata, measureContent)
    local el = nodes[index]
    for i = 1, #el.children, 1 do
        FitSizeWidth(nodes, el.children[i], index, userdata, measureContent)
    end
    local fit_width_sizing = function(el, min, max)
        el.computed_box.w = el.computed_box.w + el.padding.left + el.padding.right
        if el.layout.type == "Horizontal" then
            el.computed_box.w = el.computed_box.w + (#el.children - 1) * el.margin
        end
        if el.computed_box.w < min then
            el.computed_box.w = min
        end
        if el.computed_box.w > max and max > 0 then
            el.computed_box.w = max
        end
    end
    if el.size.x.type == "Fixed" then
        el.computed_box.w = el.size.x.value
    elseif el.size.x.type == "Fit" then
        fit_width_sizing(el, el.size.x.min, el.size.x.max)
    elseif el.size.x.type == "Grow" then
        fit_width_sizing(el, el.size.x.min, el.size.x.max)
        el.computed_box.w = math.max(el.computed_box.w, measureContent(userdata, el.painter).x)
    end
    if parent_id == nil then
        return
    end
    local parent = nodes[parent_id]
    if parent.layout.type == "Horizontal" then
        parent.computed_box.w = parent.computed_box.w + el.computed_box.w
    elseif parent.layout.type == "Vertical" then
        parent.computed_box.w = math.max(parent.computed_box.w, el.computed_box.w)
    elseif parent.layout.type == "Stack" then
        parent.computed_box.w = math.max(parent.computed_box.w, el.computed_box.w)
    end
end

local function ShrinkSizeWidth(nodes, parent_id)
    local parent = nodes[parent_id]
    local remaining = internals.get_remaining(nodes, parent_id)
    local growable = internals.get_growable(nodes, parent_id, "X")

    if parent.layout.type == "Horizontal" then
        internals.shrink_along_axis_to_min(growable)
    elseif parent.layout.type == "Vertical" then
        internals.grow_across_axis(growable, remaining.x)
    elseif parent.layout.type == "Stack" then
        internals.grow_across_axis(growable, remaining.x)
    end

    internals.apply_grow_values(nodes, growable, "X")

    for index, child in ipairs(parent.children) do
        ShrinkSizeWidth(nodes, child)
    end
end

local function GrowSizeWidth(nodes, parent_id)
    local parent = nodes[parent_id]
    local remaining = internals.get_remaining(nodes, parent_id)
    local growable = internals.get_growable(nodes, parent_id, "X")

    if parent.layout.type == "Horizontal" then
        internals.grow_along_axis(growable, remaining.x)
    elseif parent.layout.type == "Vertical" then
        internals.grow_across_axis(growable, remaining.x)
    elseif parent.layout.type == "Stack" then
        internals.grow_across_axis(growable, remaining.x)
    end

    internals.apply_grow_values(nodes, growable, "X")

    for index, child in ipairs(parent.children) do
        GrowSizeWidth(nodes, child)
    end
end

local function Wrap(nodes, el_id, userdata, wrap_content)
    local el = nodes[el_id]
    el.computed_box.h = wrap_content(userdata, el.painter, el.computed_box.w)
    for index, child in ipairs(el.children) do
        Wrap(nodes, child, userdata, wrap_content)
    end
end

local function FitSizeHeigh(nodes, index, parent_id, userdata, measureContent)
    local el = nodes[index]
    for i = 1, #el.children, 1 do
        FitSizeHeigh(nodes, el.children[i], index, userdata, measureContent)
    end
    local fit_height_sizing = function(el, min, max)
        el.computed_box.h = el.computed_box.h + el.padding.top + el.padding.bottom
        if el.layout.type == "Vertical" then
            el.computed_box.h = el.computed_box.h + (#el.children - 1) * el.margin
        end
        if el.computed_box.h < min then
            el.computed_box.h = min
        end
        if el.computed_box.h > max and max > 0 then
            el.computed_box.h = max
        end
    end

    if el.size.y.type == "Fixed" then
        el.computed_box.h = el.size.y.value
    elseif el.size.y.type == "Fit" then
        fit_height_sizing(el, el.size.y.min, el.size.y.max)
    elseif el.size.y.type == "Grow" then
        fit_height_sizing(el, el.size.y.min, el.size.y.max)
        el.computed_box.h = math.max(el.computed_box.h, measureContent(userdata, el.painter).y)
    end
    if parent_id == nil then
        return
    end
    local parent = nodes[parent_id]
    if parent.layout.type == "Horizontal" then
        parent.computed_box.h = math.max(el.computed_box.h, parent.computed_box.h)
    elseif parent.layout.type == "Vertical" then
        parent.computed_box.h = parent.computed_box.h + el.computed_box.h
    elseif parent.layout.type == "Stack" then
        parent.computed_box.h = math.max(el.computed_box.h, parent.computed_box.h)
    end
end

local function ShrinkSizeHeight(nodes, parent_id)
    local parent = nodes[parent_id]
    local remaining = internals.get_remaining(nodes, parent_id)
    local growable = internals.get_growable(nodes, parent_id, "Y")

    if parent.layout.type == "Horizontal" then
        internals.grow_across_axis(growable, remaining.y)
    elseif parent.layout.type == "Vertical" then
        internals.shrink_along_axis_to_min(growable)
    elseif parent.layout.type == "Stack" then
        internals.grow_across_axis(growable, remaining.y)
    end

    internals.apply_grow_values(nodes, growable, "Y")

    for index, child in ipairs(parent.children) do
        ShrinkSizeHeight(nodes, child)
    end
end

local function GrowSizeHeigth(nodes, parent_id)
    local parent = nodes[parent_id]
    local remaining = internals.get_remaining(nodes, parent_id)
    local growable = internals.get_growable(nodes, parent_id, "Y")

    if parent.layout.type == "Horizontal" then
        internals.grow_across_axis(growable, remaining.y)
    elseif parent.layout.type == "Vertical" then
        internals.grow_along_axis(growable, remaining.y)
    elseif parent.layout.type == "Stack" then
        internals.grow_across_axis(growable, remaining.y)
    end

    internals.apply_grow_values(nodes, growable, "Y")

    for index, child in ipairs(parent.children) do
        GrowSizeHeigth(nodes, child)
    end
end

local function Position(nodes, index, x, y)
    local self = nodes[index]
    local remaining = internals.get_remaining(nodes, index)
    local align = {
        x = internals.compute_align(self.align.x, remaining.x),
        y = internals.compute_align(self.align.y, remaining.y),
    }

    self.computed_box.x = self.pos.x + x
    self.computed_box.y = self.pos.y + y

    local offset = { x = self.padding.left, y = self.padding.top }
    for index, child_id in ipairs(self.children) do
        local child = nodes[child_id]
        if self.layout.type == "Horizontal" then
            local remaining = self.computed_box.h - self.padding.top - self.padding.bottom - child.computed_box.h
            align.y = internals.compute_align(self.align.y, remaining)
        elseif self.layout.type == "Vertical" then
            local remaining = self.computed_box.w - self.padding.left - self.padding.right - child.computed_box.w
            align.x = internals.compute_align(self.align.x, remaining)
        elseif self.layout.type == "Stack" then
            local remaining = self.computed_box.h - self.padding.top - self.padding.bottom - child.computed_box.h
            align.y = internals.compute_align(self.align.y, remaining)
            remaining = self.computed_box.w - self.padding.left - self.padding.right - child.computed_box.w
            align.x = internals.compute_align(self.align.x, remaining)
        end
        Position(nodes, child_id, self.computed_box.x + offset.x + align.x, self.computed_box.y + offset.y + align.y)

        if self.layout.type == "Horizontal" then
            offset.x = offset.x + nodes[child_id].computed_box.w + self.margin
        elseif self.layout.type == "Vertical" then
            offset.y = offset.y + nodes[child_id].computed_box.h + self.margin
        elseif self.layout.type == "Stack" then
        end
    end
end

local function DrawCommand(nodes, index, commands)
    local self = nodes[index]
    table.insert(commands, {
        x       = self.computed_box.x,
        y       = self.computed_box.y,
        w       = self.computed_box.w,
        h       = self.computed_box.h,
        painter = self.painter,
    })
    for index, child in ipairs(self.children) do
        DrawCommand(nodes, child, commands)
    end
end

return {
    FitSizeWidth = FitSizeWidth,
    ShrinkSizeWidth = ShrinkSizeWidth,
    GrowSizeWidth = GrowSizeWidth,
    Wrap = Wrap,
    FitSizeHeigh = FitSizeHeigh,
    ShrinkSizeHeight = ShrinkSizeHeight,
    GrowSizeHeigth = GrowSizeHeigth,
    Position = Position,
    DrawCommand = DrawCommand,
}
