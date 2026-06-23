local check  = require("lib.check")
local config = require("config")

local M = {}
local AnimTile = {}
AnimTile.__index = AnimTile

function M.new(value, from_row, from_col, to_row, to_col, duration, merged)
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
        merged   = merged or false,
        scale    = 1.0,
        _timer   = 0,
        _duration = duration,
        _merge_timer = 0,
    }, AnimTile)
end

function AnimTile:update(dt)
    check.num(dt, "dt")
    local remaining = dt
    if self._timer < self._duration then
        local consumed = math.min(remaining, self._duration - self._timer)
        self._timer = self._timer + consumed
        remaining = remaining - consumed
        if self._timer >= self._duration and self.merged then
            self._merge_timer = config.MERGE_EFFECT_DURATION
        end
    end
    if self._timer >= self._duration and self._merge_timer > 0 then
        self._merge_timer = math.max(0, self._merge_timer - remaining)
    end
    if self.merged and self._merge_timer > 0 then
        local elapsed = config.MERGE_EFFECT_DURATION - self._merge_timer
        local frac    = elapsed / config.MERGE_EFFECT_DURATION
        self.scale    = 1.0 + 0.2 * math.sin(frac * math.pi)
    else
        self.scale = 1.0
    end
end

function AnimTile:is_done()
    if self._timer < self._duration then return false end
    if self.merged then return self._merge_timer <= 0 end
    return true
end

function AnimTile:progress()
    return math.min(self._timer / self._duration, 1)
end

function AnimTile:finish()
    self._timer = self._duration
    self._merge_timer = 0
    self.scale = 1.0
end

return M
