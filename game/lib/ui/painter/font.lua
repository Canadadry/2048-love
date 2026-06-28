local utf8 = require("utf8")

local Font = {}
Font.__index = Font

function Font.new(opts)
    return setmetatable({
        size         = opts.size,
        spacing      = opts.spacing or 0,
        line_spacing = opts.line_spacing or 0,
        align        = opts.align or { x = "begin", y = "begin" },
        family       = opts.family or 0,
        painter      = opts.painter,
    }, Font)
end

local SPACE_CP = 32

local function advance(painter, cp, size, spacing, family)
    return painter:measure_rune(cp, size, family) + spacing
end

local function measure_str(painter, str, size, spacing, family)
    local w = 0
    for _, cp in utf8.codes(str) do
        w = w + advance(painter, cp, size, spacing, family)
    end
    return w
end

-- Returns list of {str, width} pairs, word-wrapped to max_width.
-- max_width == 0 means no word-wrap (explicit \n only).
local function wrap_text(painter, txt, size, spacing, family, max_width)
    if not txt or txt == "" then return {} end

    local space_w = advance(painter, SPACE_CP, size, spacing, family)
    local lines = {}

    local segs = {}
    for seg in (txt .. "\n"):gmatch("([^\n]*)\n") do
        segs[#segs + 1] = seg
    end
    if txt:sub(-1) == "\n" then
        segs[#segs] = nil
    end

    for _, seg in ipairs(segs) do
        if seg == "" then
            lines[#lines + 1] = { str = "", width = 0 }
        else
            local words = {}
            for word in (seg .. " "):gmatch("([^ ]*) ") do
                if word ~= "" then words[#words + 1] = word end
            end

            local cur_str, cur_w = "", 0
            for _, word in ipairs(words) do
                local ww = measure_str(painter, word, size, spacing, family)
                if cur_w == 0 then
                    cur_str, cur_w = word, ww
                elseif max_width == 0 or cur_w + space_w + ww <= max_width then
                    cur_str = cur_str .. " " .. word
                    cur_w   = cur_w + space_w + ww
                else
                    lines[#lines + 1] = { str = cur_str, width = cur_w }
                    cur_str, cur_w = word, ww
                end
            end
            if cur_str ~= "" then
                lines[#lines + 1] = { str = cur_str, width = cur_w }
            end
        end
    end

    return lines
end

function Font:measureText(txt, max_width)
    local lines = wrap_text(self.painter, txt, self.size, self.spacing, self.family, max_width)
    if #lines == 0 then return { x = 0, y = 0 } end

    local max_w = 0
    for _, line in ipairs(lines) do
        if line.width > max_w then max_w = line.width end
    end

    local h = #lines * self.size + (#lines - 1) * self.line_spacing
    return { x = max_w, y = h }
end

function Font:draw(txt, rect)
    local lines = wrap_text(self.painter, txt, self.size, self.spacing, self.family, rect.width)
    if #lines == 0 then return end

    local total_h = #lines * self.size + (#lines - 1) * self.line_spacing

    local y0 = rect.y
    if self.align.y == "middle" then
        y0 = rect.y + math.floor((rect.height - total_h) / 2)
    elseif self.align.y == "end" then
        y0 = rect.y + rect.height - total_h
    end

    for i, line in ipairs(lines) do
        local y = y0 + (i - 1) * (self.size + self.line_spacing)

        local x0 = rect.x
        if self.align.x == "middle" then
            x0 = rect.x + math.floor((rect.width - line.width) / 2)
        elseif self.align.x == "end" then
            x0 = rect.x + rect.width - line.width
        end

        local x = x0
        for _, cp in utf8.codes(line.str) do
            self.painter:draw_rune(x, y, cp, self.size, self.family)
            x = x + advance(self.painter, cp, self.size, self.spacing, self.family)
        end
    end
end

return Font
