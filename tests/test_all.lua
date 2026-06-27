-- Run from: cd game && lua ../tests/test_all.lua
local T = require("lib.t")

T.run_test_suite({
    -- reset love before each suite: some suites replace it wholesale,
    -- which would otherwise leak into later suites
    before_each = function()
        love = {
            graphics   = { getDimensions = function() return 600, 600 end },
            filesystem = {
                getDirectoryItems = function(_) return {} end,
                read              = function(_) return nil end,
                write             = function(_, _) return true end,
            },
        }
    end,
})
