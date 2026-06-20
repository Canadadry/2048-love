local gamestate = require("gamestate")

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

local function idle_board()
    return gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
end

-- ── Tracer bullet ─────────────────────────────────────────────────────────────

test("escape while idle enters pause", function()
    local s = idle_board()
    s:keypressed("escape")
    eq(s:paused(), true, "paused() should be true after Escape")
end)

-- ── Resume ────────────────────────────────────────────────────────────────────

test("escape while paused resumes", function()
    local s = idle_board()
    s:keypressed("escape")
    s:keypressed("escape")
    eq(s:paused(), false, "paused() should be false after second Escape")
end)

-- ── Pending during animation ──────────────────────────────────────────────────

test("escape mid-animation does not pause immediately", function()
    local s = idle_board()
    s:keypressed("left")          -- triggers animation
    s:keypressed("escape")        -- pressed during animation
    eq(s:paused(), false, "should not pause while animating")
end)

test("escape mid-animation pauses after animation drains", function()
    local s = idle_board()
    s:keypressed("left")
    s:keypressed("escape")
    s:update(1.0)                 -- drain animation
    eq(s:paused(), true, "should be paused once animation finishes")
end)

-- ── Queue discarded on pause ──────────────────────────────────────────────────

test("queued moves are discarded when pause opens", function()
    local s = idle_board()
    s:keypressed("left")          -- triggers animation, queues a second move context
    s:queue_move("right")         -- queue a move during animation
    s:keypressed("escape")        -- set pause pending
    s:update(1.0)                 -- animation drains → pause opens, queue cleared
    eq(s:paused(), true, "paused")
    s:keypressed("escape")        -- resume
    s:update(0)                   -- tick: no move should fire
    local score_after_resume = s:score()
    s:update(0)
    eq(s:score(), score_after_resume, "no move should fire after resume (queue was cleared)")
end)

-- ── pause_cursor ──────────────────────────────────────────────────────────────

test("pause_cursor starts at 0 when menu opens", function()
    local s = idle_board()
    s:keypressed("escape")
    eq(s:pause_cursor(), 0, "cursor starts at 0 (Resume)")
end)

test("pause_cursor moves down with down key", function()
    local s = idle_board()
    s:keypressed("escape")
    s:keypressed("down")
    eq(s:pause_cursor(), 1, "cursor at 1 after down")
    s:keypressed("down")
    eq(s:pause_cursor(), 2, "cursor at 2 after second down")
end)

test("pause_cursor clamps at 2", function()
    local s = idle_board()
    s:keypressed("escape")
    s:keypressed("down"); s:keypressed("down"); s:keypressed("down")
    eq(s:pause_cursor(), 2, "cursor clamped at 2")
end)

test("pause_cursor moves up and clamps at 0", function()
    local s = idle_board()
    s:keypressed("escape")
    s:keypressed("down")
    s:keypressed("up")
    eq(s:pause_cursor(), 0, "cursor back to 0")
    s:keypressed("up")
    eq(s:pause_cursor(), 0, "cursor clamped at 0")
end)

-- ── Enter actions ─────────────────────────────────────────────────────────────

test("enter with cursor=0 (Resume) clears paused", function()
    local s = idle_board()
    s:keypressed("escape")
    eq(s:pause_cursor(), 0, "cursor is 0")
    s:keypressed("return")
    eq(s:paused(), false, "resumed via Enter")
end)

test("enter with cursor=1 (New Game) resets score and clears paused", function()
    local s = gamestate.new_from({
        {2, 2, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    local score = s:score()
    eq(score > 0, true, "has nonzero score after merge")
    s:keypressed("escape")
    s:keypressed("down")          -- cursor → 1 (New Game)
    s:keypressed("return")
    eq(s:paused(), false, "no longer paused")
    eq(s:score(), 0, "score reset")
end)

-- ── Escape ignored during win / game-over ─────────────────────────────────────

test("escape ignored while win overlay is showing", function()
    local s = gamestate.new_from({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    eq(s:win(), true, "win overlay active")
    s:keypressed("escape")
    eq(s:paused(), false, "escape ignored during win")
    eq(s:win(), true, "win overlay still showing")
end)

test("escape ignored while game-over overlay is showing", function()
    local s = gamestate.new_from({
        {2, 4, 2, 4},
        {4, 2, 4, 2},
        {2, 4, 2, 4},
        {4, 2, 4, 2},
    })
    s:keypressed("left")
    s:update(1.0)
    eq(s:game_over(), true, "game over active")
    s:keypressed("escape")
    eq(s:paused(), false, "escape ignored during game-over")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
