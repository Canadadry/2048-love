local check = require("check")

local M = {}
local Swipe = {}
Swipe.__index = Swipe

function M.new(threshold_px)
    check.num(threshold_px, "threshold_px")
    assert(threshold_px > 0, "threshold_px must be positive, got " .. tostring(threshold_px))
    return setmetatable({ _threshold = threshold_px, _starts = {} }, Swipe)
end

function Swipe:set_threshold(px)
    check.num(px, "px")
    assert(px > 0, "threshold must be positive, got " .. tostring(px))
    self._threshold = px
end

function Swipe:touchpressed(id, x, y)
    check.num(x, "x")
    check.num(y, "y")
    self._starts[id] = { x = x, y = y, fired = false }
end

function Swipe:touchmoved(id, x, y)
    check.num(x, "x")
    check.num(y, "y")
    local s = self._starts[id]
    if not s then return nil end
    if s.fired then return nil end
    local dx = x - s.x
    local dy = y - s.y
    if math.max(math.abs(dx), math.abs(dy)) < self._threshold then return nil end
    s.fired = true
    if math.abs(dx) >= math.abs(dy) then
        return dx > 0 and "right" or "left"
    else
        return dy > 0 and "down" or "up"
    end
end

function Swipe:touchreleased(id, x, y)
    check.num(x, "x")
    check.num(y, "y")
    local s = self._starts[id]
    if not s then return nil end
    self._starts[id] = nil
    if s.fired then return nil end
    local dx = x - s.x
    local dy = y - s.y
    if math.max(math.abs(dx), math.abs(dy)) < self._threshold then return nil end
    if math.abs(dx) >= math.abs(dy) then
        return dx > 0 and "right" or "left"
    else
        return dy > 0 and "down" or "up"
    end
end

return M
