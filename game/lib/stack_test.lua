local stack = require("lib.stack")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("new(initial) makes initial the top", function()
    local initial = {}
    local s = stack.new(initial)
    eq(s:top(), initial, "top() must return the initial item")
end)

-- ── Cycle 2: push() makes the pushed item the new top ────────────────────────

test("push(item) makes item the new top", function()
    local initial, pushed = {}, {}
    local s = stack.new(initial)
    s:push(pushed)
    eq(s:top(), pushed, "top() must return the pushed item")
end)

-- ── Cycle 3: pop() removes and returns the top, reverting to the previous one ─

test("pop() returns the removed item and reverts top to the previous one", function()
    local initial, pushed = {}, {}
    local s = stack.new(initial)
    s:push(pushed)
    local removed = s:pop()
    eq(removed, pushed, "pop() must return the item that was removed")
    eq(s:top(), initial, "top() must revert to the item beneath")
end)

-- ── Cycle 4: pop() on an empty stack raises an error ─────────────────────────

test("pop() on an empty stack raises an error", function()
    local s = stack.new({})
    s:pop()
    local ok = pcall(function() s:pop() end)
    eq(ok, false, "popping an already-empty stack must error")
end)

-- ── Cycle 5: size() counts every pushed item ──────────────────────────────────

test("size() reflects the number of items", function()
    local s = stack.new({})
    s:push({})
    s:push({})
    eq(s:size(), 3, "size() must count every pushed item")
end)

-- ── Cycle 6: for_each() visits items bottom-to-top ────────────────────────────

test("for_each() visits items bottom-to-top", function()
    local bottom, middle, top = {}, {}, {}
    local s = stack.new(bottom)
    s:push(middle)
    s:push(top)
    local visited = {}
    s:for_each(function(item) visited[#visited + 1] = item end)
    eq(#visited, 3, "for_each() must visit every item")
    eq(visited[1], bottom, "for_each() visits the bottom first")
    eq(visited[2], middle, "for_each() visits the middle second")
    eq(visited[3], top, "for_each() visits the top last")
end)

-- ── Cycle 7: rev_for_each() visits items top-to-bottom ────────────────────────

test("rev_for_each() visits items top-to-bottom", function()
    local bottom, middle, top = {}, {}, {}
    local s = stack.new(bottom)
    s:push(middle)
    s:push(top)
    local visited = {}
    s:rev_for_each(function(item) visited[#visited + 1] = item end)
    eq(#visited, 3, "rev_for_each() must visit every item")
    eq(visited[1], top, "rev_for_each() visits the top first")
    eq(visited[2], middle, "rev_for_each() visits the middle second")
    eq(visited[3], bottom, "rev_for_each() visits the bottom last")
end)

T.report()
