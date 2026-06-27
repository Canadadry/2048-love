local M = {}

-- Pure position calculation; exposed for testing.
-- Returns out_x, out_y, in_x, in_y at the given progress (0→1).
function M.push_offsets(dir, progress, w, h)
    if dir == "left" then
        return -w * progress, 0, w * (1 - progress), 0
    elseif dir == "right" then
        return w * progress, 0, -w * (1 - progress), 0
    elseif dir == "up" then
        return 0, -h * progress, 0, h * (1 - progress)
    else -- "down"
        return 0, h * progress, 0, -h * (1 - progress)
    end
end

-- Factory: returns fn(canvas_out, canvas_in, progress) that composites a push transition.
function M.push(dir)
    return function(canvas_out, canvas_in, progress)
        local w, h = love.graphics.getDimensions()
        local ox, oy, ix, iy = M.push_offsets(dir, progress, w, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas_out, ox, oy)
        love.graphics.draw(canvas_in,  ix, iy)
    end
end

return M
