local kind = require("lib.ui.layout.kind")
local nine_patch = require("lib.ui.painter.nine_patch")
local ui = require("lib.ui.layout.ui")

local function Rectangle(param)
    param = param or {}
    return kind.Set({
        kind = "Rectangle",
        rounded = param.rounded or 0,
        segment = param.segment or 10,
        color = param.color or { 255, 0, 0, 255 }
    }, "Painter")
end

local function Image(param)
    param = param or {}
    return kind.Set({
        kind = "Image",
        source = param.src,
        width = param.src:getPixelWidth(),
        height = param.src:getPixelHeight(),
        color = param.color or { 255, 255, 255, 255 }
    }, "Painter")
end

local function NinePatch(param)
    param = param or {}
    return kind.Set({
        kind = "9Patch",
        patch = nine_patch.load(param.src, param.left, param.top, param.right, param.bottom),
        color = param.color or { 255, 255, 255, 255 }
    }, "Painter")
end

local function Text(param)
    param = param or {}
    return kind.Set({
        kind = "Text",
        debug = param.debug,
        text = param.text or "Text",
        align = param.align or "left",
        font = param.font or love.graphics.getFont(),
        color = param.color or { 255, 255, 255, 255 }
    }, "Painter")
end

local function Object(param)
    return kind.Set({
        kind = "Object",
        data = param.data,
        draw = param.draw,
        measure = param.measure,
        wrap = param.wrap,
    }, "Painter")
end

local function Interactive(param)
    param = param or {}
    return kind.Set({
        kind = "Interactive",
        onTap = param.onTap,
    }, "Painter")
end

local function Group(param)
    param = param or {}
    local painters = param.painters or {}
    for _, p in ipairs(painters) do
        kind.Check(p, "Painter")
    end
    return kind.Set({
        kind = "Group",
        painters = painters,
    }, "Painter")
end

local function Draw(box, painter)
    kind.Check(painter, "Painter")
    if painter.kind == "Rectangle" then
        love.graphics.setColor(painter.color[1] / 255, painter.color[2] / 255, painter.color[3] / 255,
            painter.color[4] / 255)
        love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, painter.rounded, painter.rounded, painter.segment)
    elseif painter.kind == "Image" then
        love.graphics.setColor(painter.color[1] / 255, painter.color[2] / 255, painter.color[3] / 255,
            painter.color[4] / 255)
        local sx = box.w / painter.width
        local sy = box.h / painter.height
        local s = math.min(sx, sy)
        love.graphics.draw(painter.source, box.x, box.y, 0, s, s)
    elseif painter.kind == "9Patch" then
        love.graphics.setColor(painter.color[1] / 255, painter.color[2] / 255, painter.color[3] / 255,
            painter.color[4] / 255)
        nine_patch.draw(painter.patch, box.x, box.y, box.w, box.h)
    elseif painter.kind == "Text" then
        if painter.debug then
            love.graphics.setColor(painter.debug[1] / 255, painter.debug[2] / 255, painter.debug[3] / 255,
                painter.debug[4] / 255)
            love.graphics.rectangle("fill", box.x, box.y, box.w, box.h)
        end
        love.graphics.setFont(painter.font)
        local _, wrapped_text = painter.font:getWrap(painter.text, box.w)
        love.graphics.setColor(painter.color[1] / 255, painter.color[2] / 255, painter.color[3] / 255,
            painter.color[4] / 255)
        love.graphics.printf(wrapped_text, box.x, box.y, box.w, painter.align)
    elseif painter.kind == "Object" then
        painter.draw(painter.data, box.x, box.y, box.w, box.h)
    elseif painter.kind == "Interactive" then
        -- invisible: only matters to ui.HitTest
    elseif painter.kind == "Group" then
        for _, p in ipairs(painter.painters) do
            Draw(box, p)
        end
    end
end

local function DrawTree(tree)
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter then
            Draw(cmd, cmd.painter)
        end
    end
end

local function count_lines(text)
    local count = 0
    for _ in string.gmatch(text, "[^\n]*") do
        count = count + 1
    end
    return count
end

local function Measure(userdata, painter)
    if painter == nil then
        return { x = 0, y = 0 }
    end
    if painter.kind == "Rectangle" then
        return { x = 1, y = 1 }
    elseif painter.kind == "9Patch" then
        return { x = 1, y = 1 }
    elseif painter.kind == "Image" then
        return { x = painter.width, y = painter.height }
    elseif painter.kind == "Text" then
        local w = painter.font:getWidth(painter.text)
        local h = painter.font:getHeight() * count_lines(painter.text)
        return { x = w, y = h }
    elseif painter.kind == "Object" then
        return painter.measure(painter.data)
    elseif painter.kind == "Interactive" then
        return { x = 0, y = 0 }
    elseif painter.kind == "Group" then
        local mx, my = 0, 0
        for _, p in ipairs(painter.painters) do
            local m = Measure(userdata, p)
            mx = math.max(mx, m.x)
            my = math.max(my, m.y)
        end
        return { x = mx, y = my }
    end
    if painter.kind == nil then
        error("invalid painter : no kind")
    end
    error("invalid painter " .. painter.kind)
end

local function Wrap(userdata, painter, width)
    if painter == nil then
        return 0
    end
    if painter.kind == "Rectangle" then
        return 1
    elseif painter.kind == "9Patch" then
        return 1
    elseif painter.kind == "Image" then
        local s = width / painter.width
        return painter.height * s
    elseif painter.kind == "Text" then
        local _, wrapped_text = painter.font:getWrap(painter.text, width)
        return painter.font:getHeight() * #wrapped_text
    elseif painter.kind == "Object" then
        return painter.measure(painter.data, width)
    elseif painter.kind == "Interactive" then
        return 0
    elseif painter.kind == "Group" then
        local m = 0
        for _, p in ipairs(painter.painters) do
            m = math.max(m, Wrap(userdata, p, width))
        end
        return m
    end
    error("invalid painter " .. painter.kind)
end

local function Tree()
    return ui.Tree({
        measureContent = Measure,
        wrapContent = Wrap,
    })()
end

return {
    Rectangle = Rectangle,
    Text = Text,
    Image = Image,
    NinePatch = NinePatch,
    Object = Object,
    Interactive = Interactive,
    Group = Group,
    Draw = Draw,
    DrawTree = DrawTree,
    Measure = Measure,
    Wrap = Wrap,
    Tree = Tree,
}
