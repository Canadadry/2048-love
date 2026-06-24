local menu_screen = require("lib.menu_screen")

local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("PASS " .. name)
        pass = pass + 1
    else
        print("FAIL " .. name)
        print("     " .. tostring(err))
        fail = fail + 1
    end
end

local function eq(a, b, msg)
    if a ~= b then
        error((msg or "eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

local function spy()
    local s = { count = 0 }
    s.fn = function() s.count = s.count + 1 end
    return s
end

local function action_items(n)
    local spies = {}
    local items = {}
    for i = 1, n do
        spies[i] = spy()
        items[i] = { label = "item" .. i, on_activate = spies[i].fn }
    end
    return items, spies
end

local function value_item(value)
    local s = spy()
    return { label = "row", value = value, on_right = s.fn }, s
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("cursor defaults to 0", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items })
    eq(screen:cursor(), 0, "cursor starts at 0")
end)

test("items() exposes the configured items list, for view-layer wiring", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items })
    eq(screen:items(), items, "items() returns the same list passed to new()")
end)

-- ── Cycle 2: down moves the cursor forward by one ────────────────────────────

test("down moves the cursor forward by one", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items })
    screen:keypressed("down")
    eq(screen:cursor(), 1, "cursor at 1 after down")
end)

-- ── Cycle 3: down clamps at the last item when wrap is false ─────────────────

test("down clamps at the last item", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items })
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 2, "cursor clamped at 2")
end)

-- ── Cycle 4: up moves back and clamps at 0 ────────────────────────────────────

test("up moves the cursor back and clamps at 0", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items })
    screen:keypressed("down")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor back to 0")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor clamped at 0")
end)

-- ── Cycle 5: wrap = true wraps at both ends instead of clamping ──────────────

test("down wraps from the last item to the first when wrap is true", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items, wrap = true })
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 0, "down wraps from item 3 back to item 1")
end)

test("up wraps from the first item to the last when wrap is true", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items, wrap = true })
    screen:keypressed("up")
    eq(screen:cursor(), 2, "up wraps from item 1 to item 3")
end)

-- ── Cycle 6: Return activates the current item ───────────────────────────────

test("Return calls on_activate of the current item, and no other item's", function()
    local items, spies = action_items(3)
    local screen = menu_screen.new({ items = items })
    screen:keypressed("down")
    screen:keypressed("return")
    eq(spies[1].count, 0, "item 1 not activated")
    eq(spies[2].count, 1, "item 2 (current) activated")
    eq(spies[3].count, 0, "item 3 not activated")
end)

-- ── Cycle 7: tap(i) activates a plain item regardless of current cursor ─────

test("tap(i) activates item i's on_activate even when cursor is elsewhere", function()
    local items, spies = action_items(3)
    local screen = menu_screen.new({ items = items })
    screen:tap(3)
    eq(screen:cursor(), 0, "cursor untouched by tapping a plain action item")
    eq(spies[1].count, 0, "item 1 not activated")
    eq(spies[3].count, 1, "item 3 (tapped) activated")
end)

-- ── Cycle 8: tap-to-focus then tap-to-cycle for a value-bearing item ─────────

test("tapping an unfocused value item only focuses it, without cycling", function()
    local row, row_spy = value_item(true)
    local items = { { label = "other" }, row }
    local screen = menu_screen.new({ items = items })
    screen:tap(2)
    eq(screen:cursor(), 1, "tap moved the cursor onto the row")
    eq(row_spy.count, 0, "value not cycled by a focus-only tap")
end)

test("tapping the already-focused value item calls on_right", function()
    local row, row_spy = value_item(true)
    local items = { { label = "other" }, row }
    local screen = menu_screen.new({ items = items, cursor_start = 1 })
    screen:tap(2)
    eq(row_spy.count, 1, "second tap on the focused row cycles via on_right")
end)

-- ── Cycle 9: Left/Right on the current item call on_left/on_right ───────────

test("Right calls on_right of the current item", function()
    local right_spy = spy()
    local left_spy   = spy()
    local items = { { label = "row", value = true, on_left = left_spy.fn, on_right = right_spy.fn } }
    local screen = menu_screen.new({ items = items })
    screen:keypressed("right")
    eq(right_spy.count, 1, "on_right called")
    eq(left_spy.count, 0, "on_left not called")
end)

test("Left calls on_left of the current item", function()
    local right_spy = spy()
    local left_spy   = spy()
    local items = { { label = "row", value = true, on_left = left_spy.fn, on_right = right_spy.fn } }
    local screen = menu_screen.new({ items = items })
    screen:keypressed("left")
    eq(left_spy.count, 1, "on_left called")
    eq(right_spy.count, 0, "on_right not called")
end)

-- ── Cycle 10: cursor movement skips non-focusable items ──────────────────────

test("down skips a non-focusable item in between", function()
    local items, spies = action_items(3)
    items[2].focusable = false
    local screen = menu_screen.new({ items = items })
    screen:keypressed("down")
    eq(screen:cursor(), 2, "down skipped item 2 and landed on item 3")
end)

test("up skips a non-focusable item in between", function()
    local items = action_items(3)
    items[2].focusable = false
    local screen = menu_screen.new({ items = items, cursor_start = 2 })
    screen:keypressed("up")
    eq(screen:cursor(), 0, "up skipped item 2 and landed on item 1")
end)

test("tap on a non-focusable item does nothing", function()
    local items, spies = action_items(3)
    items[2].focusable = false
    local screen = menu_screen.new({ items = items })
    screen:tap(2)
    eq(screen:cursor(), 0, "cursor untouched by tapping a non-focusable item")
    eq(spies[2].count, 0, "non-focusable item never activated")
end)

-- ── Cycle 12: focus_before_activate gates tap behind a focus-first tap ───────

test("tapping an unfocused focus_before_activate item only focuses it", function()
    local s = spy()
    local items = { { label = "other" }, { label = "Back", on_activate = s.fn, focus_before_activate = true } }
    local screen = menu_screen.new({ items = items })
    screen:tap(2)
    eq(screen:cursor(), 1, "tap moved the cursor onto Back")
    eq(s.count, 0, "not activated by a focus-only tap")
end)

test("tapping an already-focused focus_before_activate item calls on_activate", function()
    local s = spy()
    local items = { { label = "other" }, { label = "Back", on_activate = s.fn, focus_before_activate = true } }
    local screen = menu_screen.new({ items = items, cursor_start = 1 })
    screen:tap(2)
    eq(s.count, 1, "second tap on the focused item activates it")
end)

-- ── Cycle 11: enter() resets the cursor to cursor_start ──────────────────────

test("enter() resets the cursor back to cursor_start", function()
    local items = action_items(3)
    local screen = menu_screen.new({ items = items, cursor_start = 1 })
    screen:keypressed("down")
    eq(screen:cursor(), 2, "cursor moved to 2")
    screen:enter()
    eq(screen:cursor(), 1, "enter() reset cursor to cursor_start")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
