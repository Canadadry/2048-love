local T = require("lib.t")
local Font = require("lib.ui.painter.font")
local test_cases = require("lib.ui.painter.mesure_text_testcase")

-- measure_rune returns floor(size / 2) for any rune
local mock_painter = {
    measure_rune = function(self, rune, size, family)
        return math.floor(size / 2)
    end
}

for _, tt in ipairs(test_cases) do
    T.test("measureText: " .. tt.name, function()
        local font = Font.new({
            size         = tt.input.font.size,
            spacing      = tt.input.font.spacing or 0,
            line_spacing = tt.input.font.line_spacing or 0,
            align        = tt.input.font.align,
            painter      = mock_painter,
        })
        local got = font:measureText(tt.input.txt, tt.input.width)
        T.eq(got.x, tt.expected.x, "x")
        T.eq(got.y, tt.expected.y, "y")
    end)
end

T.report()
