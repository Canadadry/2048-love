local T = require("lib.t")
local Font = require("lib.ui.painter.font")
local test_cases = require("lib.ui.painter.draw_text_testcase")

local utf8 = require("utf8")

for _, tt in ipairs(test_cases) do
    T.test("draw: " .. tt.name, function()
        local win_w = tt.input.window.width
        local win_h = tt.input.window.height

        -- Buffer initialised with spaces (codepoint 32)
        local buf = {}
        for y = 0, win_h - 1 do
            buf[y] = {}
            for x = 0, win_w - 1 do buf[y][x] = 32 end
        end

        local painter = {
            measure_rune = function(self, rune, size, family) return 1 end,
            draw_rune    = function(self, x, y, cp, size, family)
                if y >= 0 and y < win_h and x >= 0 and x < win_w then
                    buf[y][x] = cp
                end
            end,
        }

        local font = Font.new({
            size         = tt.input.font.size,
            spacing      = tt.input.font.spacing or 0,
            line_spacing = tt.input.font.line_spacing or 0,
            align        = tt.input.font.align,
            painter      = painter,
        })

        font:draw(tt.input.txt, tt.input.rect)

        for row_i, expected_row in ipairs(tt.expected.buffer) do
            local y = row_i - 1
            if y >= win_h then break end

            local chars = {}
            for x = 0, win_w - 1 do
                chars[x + 1] = utf8.char(buf[y][x])
            end
            local actual = table.concat(chars)

            if actual ~= expected_row then
                error(string.format("row %d:\n  expected: %q\n  got:      %q", y, expected_row, actual))
            end
        end
    end)
end

T.report()
