local M = {}
local Tile = {}
Tile.__index = Tile

function M.new(value, draw_x, draw_y, target_x, target_y, anim_duration)
    return setmetatable({
        value    = value,
        draw_x   = draw_x,
        draw_y   = draw_y,
        target_x = target_x,
        target_y = target_y,
        _duration = anim_duration,
        _timer   = 0,
    }, Tile)
end

function Tile:update(dt)
    self._timer = self._timer + dt
    local t = math.min(self._timer / self._duration, 1)
    self.draw_x = self.draw_x + (self.target_x - self.draw_x) * t
    self.draw_y = self.draw_y + (self.target_y - self.draw_y) * t
    if t >= 1 then
        self.draw_x = self.target_x
        self.draw_y = self.target_y
    end
end

function Tile:is_done()
    return self._timer >= self._duration
end

return M
