local kind = require("lib.ui.layout.kind")

local function get_remaining(nodes, parent_id)
    local parent = nodes[parent_id]
    local remaining = {
        x = parent.computed_box.w - parent.padding.left - parent.padding.right,
        y = parent.computed_box.h - parent.padding.top - parent.padding.bottom,
    }

    if #parent.children == 0 then
        return remaining
    end

    if parent.layout.type == "Horizontal" then
        for index, child_id in ipairs(parent.children) do
            remaining.x = remaining.x - nodes[child_id].computed_box.w
        end
        remaining.x = remaining.x - (#parent.children - 1) * parent.margin
    elseif parent.layout.type == "Vertical" then
        for index, child_id in ipairs(parent.children) do
            remaining.y = remaining.y - nodes[child_id].computed_box.h
        end
        remaining.y = remaining.y - (#parent.children - 1) * parent.margin
    end
    return remaining
end

local function Growable(id, val, min, max)
    return {
        id = id or 0,
        val = val or 0,
        min = min or 0,
        max = max or 0,
    }
end

local function get_growable(nodes, parent_id, mode)
    local parent = nodes[parent_id]
    local growables = {}
    if mode == "X" then
        for index, child_id in ipairs(parent.children) do
            local child = nodes[child_id]
            if child.size.x.type == "Grow" then
                table.insert(growables, Growable(
                    child_id,
                    child.computed_box.w,
                    child.size.x.min,
                    child.size.x.max
                ))
            end
        end
    elseif mode == "Y" then
        for index, child_id in ipairs(parent.children) do
            local child = nodes[child_id]
            if child.size.y.type == "Grow" then
                table.insert(growables, Growable(child_id,
                    child.computed_box.h,
                    child.size.y.min,
                    child.size.y.max
                ))
            end
        end
    end

    return growables
end

local function alias(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

local function sort(t, reverse)
    local less = function(i, j)
        return i.val < j.val
    end
    local more = function(i, j)
        return i.val > j.val
    end
    local mode = less
    if reverse == true then
        mode = more
    end
    table.sort(t, mode)
end

local function add(growables, val, up_to)
    local last = math.min(up_to + 1, #growables)
    local to_remove = {}
    for i = 1, last, 1 do
        growables[i].val = growables[i].val + val
        if growables[i].val > growables[i].max and growables[i].max > 0 then
            growables[i].val = growables[i].max
            table.insert(to_remove, i)
        end
    end
    for i = #to_remove, 1, -1 do
        table.remove(growables, to_remove[i])
    end
end

local function grow_along_axis(growables, remaining)
    if #growables == 0 or remaining <= 0 then
        return
    end
    if #growables == 1 then
        growables[1].val = growables[1].val + remaining
        return
    end
    local alias_g = alias(growables)
    sort(alias_g)
    for index, growable in ipairs(alias_g) do
        if growable.val > alias_g[1].val then
            local delta = growable.val - alias_g[1].val
            delta = math.min(delta, remaining / (index - 1))
            if delta == 0 then
                break
            end
            remaining = remaining - delta * (index - 1)
            add(alias_g, delta, index - 2)
        end
        if alias_g[1].val == alias_g[#alias_g].val then
            local delta = remaining / #alias_g
            remaining = remaining - delta * #alias_g
            add(alias_g, delta, #alias_g)
            if remaining / #alias_g == 0 then
                break
            end
        end
    end
end

local function shrink_along_axis_to_min(growables)
    for index, growable in ipairs(growables) do
        growable.val = growable.min
    end
end

local function grow_across_axis(growables, remaining)
    for index, growable in ipairs(growables) do
        growable.val = remaining
    end
end

local function apply_grow_values(nodes, growables, mode)
    if mode == "X" then
        for index, growable in ipairs(growables) do
            nodes[growable.id].computed_box.w = growable.val
        end
    elseif mode == "Y" then
        for index, growable in ipairs(growables) do
            nodes[growable.id].computed_box.h = growable.val
        end
    end
end

local function compute_align(mode, remaining)
    kind.Check(mode, "Align")
    if mode.type == "Begin" then
        return 0
    elseif mode.type == "Middle" then
        return remaining / 2
    elseif mode.type == "End" then
        return remaining
    end
end

return {
    get_remaining = get_remaining,
    get_growable = get_growable,
    Growable = Growable,
    shrink_along_axis_to_min = shrink_along_axis_to_min,
    grow_along_axis = grow_along_axis,
    grow_across_axis = grow_across_axis,
    apply_grow_values = apply_grow_values,
    compute_align = compute_align,
}
