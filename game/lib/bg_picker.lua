local M = {}

function M.fit_cover(iw, ih, sw, sh, zoom)
    local scale = math.max(sw / iw, sh / ih) * zoom
    local x = (sw - iw * scale) / 2
    local y = (sh - ih * scale) / 2
    return x, y, scale
end

function M.pick(dir, rand_fn)
    local items = love.filesystem.getDirectoryItems(dir)
    local pngs = {}
    for _, f in ipairs(items) do
        if f:match("%.png$") then
            pngs[#pngs + 1] = dir .. "/" .. f
        end
    end
    if #pngs == 0 then return nil end
    rand_fn = rand_fn or math.random
    return pngs[math.ceil(rand_fn(#pngs))]
end

return M
