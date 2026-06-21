-- gamestate.lua requires "grid" which in turn is a plain Lua module, but
-- gamestate also requires no Love2D calls at construction time.
local gamestate = require("gamestate")
local config    = require("config")

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

-- Tracer bullet: after a key press that moves tiles, gamestate is animating
test("is_animating() returns true after a move that slides tiles", function()
    local s = gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    eq(s:is_animating(), true, "should be animating after a move")
end)

-- Input is blocked while animations are in flight
test("keypressed is ignored while animations are active", function()
    local s = gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    local score_after_first = s:score()
    -- second key press should be blocked
    s:keypressed("right")
    eq(s:score(), score_after_first, "score unchanged when input blocked")
end)

-- After update() completes animation, is_animating returns false
test("is_animating() returns false after animation duration elapses", function()
    local s = gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    s:update(1.0)  -- way past any animation duration
    eq(s:is_animating(), false, "animation should be done")
end)

-- ── PRD 004: Game States ─────────────────────────────────────────────────────

-- Tracer bullet: Continue from you_win overlay unfreezes the game
test("Continue (keypressed return, cursor 0) dismisses win overlay", function()
    local s = gamestate.new_from({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    eq(s:win(), true, "win overlay should be active")
    s:keypressed("return")        -- cursor defaults to 0 = Continue
    eq(s:win(), false,       "win cleared after Continue")
    eq(s:game_over(), false, "not game over")
end)

-- After Continue, further moves do not re-trigger the win overlay
test("win overlay does not reappear after Continue (win_seen)", function()
    local s = gamestate.new_from({
        {1024, 1024, 0, 0},
        {0,    2,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    s:keypressed("return")        -- Continue
    -- 2048 tile is still on the board; any further move returns win=true from
    -- grid, but win_seen must suppress the overlay
    s:keypressed("down")
    s:update(1.0)
    eq(s:win(), false, "win overlay must not reappear after Continue")
end)

-- Continue preserves the existing board (2048 tile still present)
test("Continue preserves board: 2048 tile remains after continuing", function()
    local s = gamestate.new_from({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    local score_at_win = s:score()
    s:keypressed("return")        -- Continue
    local cells = s:cells()
    local has_2048 = false
    for r = 1, 4 do
        for c = 1, 4 do
            if cells[r][c] == 2048 then has_2048 = true end
        end
    end
    eq(has_2048, true,        "2048 tile must still be on board")
    eq(s:score(), score_at_win, "score preserved after Continue")
end)

-- Cursor starts at 0 (Continue) and moves with up/down
test("cursor starts at 0 and moves down to 1, up back to 0", function()
    local s = gamestate.new_from({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    eq(s:cursor(), 0, "cursor starts at 0 (Continue)")
    s:keypressed("down")
    eq(s:cursor(), 1, "cursor at 1 (Restart) after down")
    s:keypressed("up")
    eq(s:cursor(), 0, "cursor back to 0 after up")
end)

-- Restart from you_win (cursor=1, Enter) resets board and score
test("Restart from you_win resets board to fresh state", function()
    local s = gamestate.new_from({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    s:keypressed("down")          -- cursor → 1 (Restart)
    s:keypressed("return")        -- confirm Restart
    eq(s:score(), 0, "score reset to 0")
    eq(s:win(), false, "win cleared")
    local cells = s:cells()
    local count = 0
    for r = 1, 4 do
        for c = 1, 4 do
            if cells[r][c] ~= 0 then count = count + 1 end
        end
    end
    eq(count, 2, "fresh board has exactly 2 tiles")
end)

-- continue_game() direct method (used by click/tap handler)
test("continue_game() directly dismisses win overlay without cursor change", function()
    local s = gamestate.new_from({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    s:keypressed("left")
    s:update(1.0)
    s:continue_game()
    eq(s:win(), false, "win cleared by continue_game()")
    eq(s:game_over(), false, "not game over")
end)

-- Restart from game_over via Enter
test("pressing Enter in game_over state restarts the game", function()
    local s = gamestate.new_from({
        {2, 4, 2, 4},
        {4, 2, 4, 2},
        {2, 4, 2, 4},
        {4, 2, 4, 2},
    })
    s:keypressed("left")
    s:update(1.0)
    eq(s:game_over(), true, "should be game over")
    s:keypressed("return")
    eq(s:game_over(), false, "game_over cleared after Enter")
    eq(s:score(), 0, "score reset")
end)

-- Arrow key also restarts from game_over
test("arrow key in game_over state restarts the game", function()
    local s = gamestate.new_from({
        {2, 4, 2, 4},
        {4, 2, 4, 2},
        {2, 4, 2, 4},
        {4, 2, 4, 2},
    })
    s:keypressed("left")
    s:update(1.0)
    s:keypressed("up")
    eq(s:game_over(), false, "game_over cleared by arrow key")
end)

-- ── PRD 017: Animation & Effect Toggles ──────────────────────────────────────

test("a move produces no anim_tiles when animations are disabled, snapping immediately", function()
    config.ANIMATIONS_ENABLED = false
    local s = gamestate.new_from({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    eq(s:is_animating(), false, "should not be animating when animations are disabled")
    config.ANIMATIONS_ENABLED = true
end)

test("a merge still slides but skips the pop when effects are disabled", function()
    config.EFFECTS_ENABLED = false
    local s = gamestate.new_from({
        {2, 2, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    s:keypressed("left")
    eq(s:is_animating(), true, "slide animation still runs")
    local tiles = s:anim_tiles()
    eq(#tiles > 0, true, "merge still produces sliding tiles")
    s:update(config.ANIM_DURATION + config.MERGE_EFFECT_DURATION / 2)
    for _, t in ipairs(tiles) do
        eq(t.scale, 1.0, "scale never pops when effects are disabled")
    end
    config.EFFECTS_ENABLED = true
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
