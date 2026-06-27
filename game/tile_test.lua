local tile   = require("tile")
local config = require("config")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

test("tile.is_done() is false before duration elapses", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(0.05)
    eq(t:is_done(), false, "should not be done at half duration")
end)

test("tile.is_done() is true when timer reaches duration", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(0.1)
    eq(t:is_done(), true, "should be done at exactly duration")
end)

test("tile.progress() is 0.5 at half duration", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(0.05)
    eq(t:progress(), 0.5, "progress at half duration")
end)

test("tile.progress() clamps to 1 past duration", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:update(9999)
    eq(t:progress(), 1, "progress clamps at 1")
end)

test("tile.finish() makes is_done() return true immediately", function()
    local t = tile.new(2, 1, 1, 1, 2, 0.1)
    t:finish()
    eq(t:is_done(), true, "finish() should mark tile as done")
end)

test("merged tile is not done() when slide timer reaches duration", function()
    local t = tile.new(4, 1, 1, 1, 2, 0.1, true)
    t:update(0.1)
    eq(t:is_done(), false, "merged tile should still be popping")
end)

test("merged tile becomes done() once the pop duration elapses", function()
    local t = tile.new(4, 1, 1, 1, 2, 0.1, true)
    t:update(0.1)
    t:update(config.MERGE_EFFECT_DURATION)
    eq(t:is_done(), true, "merged tile should be done after pop finishes")
end)

test("merged tile scale peaks above 1.0 at the pop's midpoint", function()
    local t = tile.new(4, 1, 1, 1, 2, 0.1, true)
    t:update(0.1)
    t:update(config.MERGE_EFFECT_DURATION / 2)
    if t.scale <= 1.0 then
        error("expected scale above 1.0 at midpoint, got " .. tostring(t.scale))
    end
end)

test("merged tile scale returns to 1.0 once the pop finishes", function()
    local t = tile.new(4, 1, 1, 1, 2, 0.1, true)
    t:update(0.1)
    t:update(config.MERGE_EFFECT_DURATION)
    eq(t.scale, 1.0, "scale should settle back to 1.0")
end)

test("finish() on a merged, mid-pop tile marks it done and resets scale", function()
    local t = tile.new(4, 1, 1, 1, 2, 0.1, true)
    t:update(0.1)
    t:update(config.MERGE_EFFECT_DURATION / 2)
    t:finish()
    eq(t:is_done(), true, "finish() should mark merged tile done")
    eq(t.scale, 1.0, "finish() should reset scale to 1.0")
end)

test("a single large dt finishes both slide and pop phase for a merged tile", function()
    local t = tile.new(4, 1, 1, 1, 2, 0.1, true)
    t:update(1.0)
    eq(t:is_done(), true, "one big update should flush slide and pop together")
end)

test("tile.new() stores row/col fields correctly", function()
    local t = tile.new(8, 2, 3, 4, 1, 0.1)
    eq(t.value,    8, "value")
    eq(t.from_row, 2, "from_row")
    eq(t.from_col, 3, "from_col")
    eq(t.to_row,   4, "to_row")
    eq(t.to_col,   1, "to_col")
end)

T.report()
