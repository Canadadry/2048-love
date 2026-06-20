local check = require("check")

local M = {}
local AnimTile = {}
AnimTile.__index = AnimTile

function M.new(value, from_row, from_col, to_row, to_col, duration)
    check.num(value,    "value")
    check.num(from_row, "from_row")
    check.num(from_col, "from_col")
    check.num(to_row,   "to_row")
    check.num(to_col,   "to_col")
    check.num(duration, "duration")
    assert(duration > 0, "duration must be positive, got " .. tostring(duration))
    return setmetatable({
        value    = value,
        from_row = from_row, from_col = from_col,
        to_row   = to_row,   to_col   = to_col,
        _timer   = 0,
        _duration = duration,
    }, AnimTile)
end

function AnimTile:update(dt)
    check.num(dt, "dt")
    self._timer = self._timer + dt
end

function AnimTile:is_done()
    return self._timer >= self._duration
end

function AnimTile:progress()
    return math.min(self._timer / self._duration, 1)
end

function AnimTile:finish()
    self._timer = self._duration
end

return M
