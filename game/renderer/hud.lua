local M = {}

function M.score_position(board_x, board_y, font_sz)
    return board_x, board_y - font_sz - 4
end

function M.draw(score, board_x, board_y, font_sz, font)
    local x, y = M.score_position(board_x, board_y, font_sz)
    love.graphics.setColor(0.47, 0.43, 0.40)
    love.graphics.setFont(font)
    love.graphics.print("Score: " .. score, x, y)
end

return M
