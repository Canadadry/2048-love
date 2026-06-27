love = {
    graphics = {
        getDimensions = function() return 600, 600 end,
        newFont       = function(size)
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 18 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
        setColor  = function(...) end,
        rectangle = function(...) end,
        draw      = function(...) end,
        printf    = function(...) end,
        print     = function(...) end,
        setFont   = function(...) end,
    },
}

local game_screen = require("screens.game_screen")
local config      = require("config")
local hud         = require("hud")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local function stub_host()
    local spawn_calls = { win = {}, game_over = {}, pause = {} }
    return {
        promote_calls = {},
        promote       = function(self, screen) table.insert(self.promote_calls, screen) end,
        replace_calls = {},
        replace       = function(self, screen) table.insert(self.replace_calls, screen) end,
        dismiss_count = 0,
        dismiss       = function(self) self.dismiss_count = self.dismiss_count + 1 end,
        quit_count    = 0,
        quit          = function(self) self.quit_count = self.quit_count + 1 end,
        spawn_calls   = spawn_calls,
        spawn         = function(self, name, game)
            table.insert(spawn_calls[name], game)
            return { spawned = name, host = self, game = game }
        end,
    }
end

-- always picks the first empty cell, spawning a 2
local function deterministic_rand(n)
    if n then return 1 end
    return 0
end

local function new_screen(cells)
    local host = stub_host()
    local screen = game_screen.new(host, cells, deterministic_rand)
    return screen, host
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("queue_move + update applies the move", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:queue_move("left")
    screen:update(1.0)
    local cells = screen:cells()
    eq(cells[1][1], 2, "first tile slid to the left edge")
    eq(cells[1][2], 4, "second tile slid next to it")
end)

-- ── Cycle 2: keypressed applies a move when idle ─────────────────────────────

test("keypressed with an arrow key applies a move when idle", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")
    local cells = screen:cells()
    eq(cells[1][1], 2, "first tile slid to the left edge")
    eq(cells[1][2], 4, "second tile slid next to it")
end)

-- ── Cycle 3: is_animating() tracks in-flight tiles ───────────────────────────

test("is_animating() returns true right after a move that slides tiles", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")
    eq(screen:is_animating(), true, "should be animating after a move")
end)

test("keypressed is ignored while animations are active", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")
    local score_after_first = screen:score()
    screen:keypressed("right")
    eq(screen:score(), score_after_first, "score unchanged when input is blocked")
end)

test("is_animating() returns false once update(dt) drains the animation", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")
    screen:update(1.0)
    eq(screen:is_animating(), false, "animation should be done")
end)

-- ── Cycle 4: Escape while idle promotes the real pause screen ────────────────

test("escape while idle promotes a pause screen wired to this game screen", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("escape")
    eq(#host.promote_calls, 1, "host:promote() called once")
    local promoted = host.promote_calls[1]
    eq(promoted.host, host, "pause screen wired to the same host")
    eq(promoted.game, screen, "pause screen wired to this game screen")
end)

-- ── Cycle 5: deferred pause mid-animation; queue discarded once it opens ─────

test("escape mid-animation does not pause immediately", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")   -- triggers animation
    screen:keypressed("escape") -- pressed during animation
    eq(#host.promote_calls, 0, "should not promote pause while animating")
end)

test("escape mid-animation pauses once the animation drains", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")
    screen:keypressed("escape")
    screen:update(1.0) -- drain animation
    eq(#host.promote_calls, 1, "pause promoted once animation finishes")
end)

test("queued moves are discarded when the deferred pause opens", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")     -- triggers animation
    screen:queue_move("right")    -- queued during animation
    screen:keypressed("escape")   -- pause pending
    screen:update(1.0)            -- animation drains -> pause opens, queue cleared
    eq(#host.promote_calls, 1, "pause promoted")
    local score_after_pause = screen:score()
    screen:update(0)
    eq(screen:score(), score_after_pause, "no queued move fires after the deferred pause opens")
end)

-- ── Cycle 6: a winning move promotes deps.make_win(self) ────────────────────

test("a move that completes the win tile promotes deps.make_win(self)", function()
    local screen, host = new_screen({
        {1024, 1024, 0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    screen:keypressed("left")
    eq(#host.promote_calls, 1, "host:promote() called once")
    eq(#host.spawn_calls.win, 1, "host:spawn('win') called once")
    eq(host.spawn_calls.win[1], screen, "host:spawn('win') received this game screen")
end)

-- ── Cycle 7: a game-ending move promotes deps.make_game_over(self) ──────────

test("a move that leaves no legal moves promotes deps.make_game_over(self)", function()
    local screen, host = new_screen({
        {2, 4, 2, 4},
        {4, 2, 4, 2},
        {2, 4, 2, 4},
        {4, 2, 4, 2},
    })
    screen:keypressed("left")
    eq(#host.promote_calls, 1, "host:promote() called once")
    eq(#host.spawn_calls.game_over, 1, "host:spawn('game_over') called once")
    eq(host.spawn_calls.game_over[1], screen, "host:spawn('game_over') received this game screen")
end)

-- ── Cycle 8: win+game_over on the same move promotes only Win ───────────────

test("a move that both wins and ends the game promotes only Win, never Game Over", function()
    -- fully locked board (no zeros, no adjacent equal pairs in any direction)
    -- that already contains the win tile -- moved=false, win=true, game_over=true
    local screen, host = new_screen({
        {2048, 4, 2, 4},
        {4,    2, 4, 2},
        {2,    4, 2, 4},
        {4,    2, 4, 2},
    })
    screen:keypressed("left")
    eq(#host.spawn_calls.win, 1, "Win promoted")
    eq(#host.spawn_calls.game_over, 0, "Game Over must not be promoted on the same move")
end)

-- ── Cycle 9: mark_win_seen() suppresses a later win promotion this game ─────

test("mark_win_seen() suppresses the win overlay on a later winning move", function()
    local screen, host = new_screen({
        {1024, 1024, 0, 0},
        {0,    2,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    screen:keypressed("left")
    screen:update(1.0) -- drain the slide animation so the next keypress isn't blocked
    eq(#host.spawn_calls.win, 1, "Win promoted on the winning move")
    screen:mark_win_seen()
    screen:keypressed("down") -- 2048 tile still on board; would re-trigger win if not for win_seen
    eq(#host.spawn_calls.win, 1, "Win must not be promoted again after mark_win_seen()")
end)

-- ── Cycle 10: restart() resets grid/score/tiles/queue/win_seen/pause_pending ──

test("restart() resets the score and gives a fresh two-tile board", function()
    local screen = new_screen({
        {2, 2, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")
    screen:update(1.0)
    eq(screen:score() > 0, true, "has nonzero score after a merge")
    screen:restart()
    eq(screen:score(), 0, "score reset to 0")
    eq(screen:is_animating(), false, "no leftover animation after restart")
    local cells = screen:cells()
    local count = 0
    for r = 1, 4 do
        for c = 1, 4 do
            if cells[r][c] ~= 0 then count = count + 1 end
        end
    end
    eq(count, 2, "fresh board has exactly 2 tiles")
end)

test("restart() clears win_seen so a later win is promoted again", function()
    local screen, host = new_screen({
        {1024, 1024, 0, 0},
        {0,    2,    0, 0},
        {0,    0,    0, 0},
        {0,    0,    0, 0},
    })
    screen:keypressed("left")
    screen:update(1.0)
    eq(#host.spawn_calls.win, 1, "Win promoted on the winning move")
    screen:mark_win_seen()
    screen:restart()
    -- restart() rebuilds the grid with the same injected deterministic rand,
    -- so the fresh board is always {2,2,0,...}; lowering WIN_TILE to 2 lets a
    -- single move re-trigger win without needing a fresh winning board.
    config.WIN_TILE = 2
    screen:keypressed("right")
    config.WIN_TILE = 2048
    eq(#host.spawn_calls.win, 2, "Win promoted again after restart clears win_seen")
end)

test("restart() clears pause_pending and the move queue", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")   -- triggers animation
    screen:queue_move("right")  -- queued during animation
    screen:keypressed("escape") -- pause pending
    screen:restart()
    screen:update(1.0)
    eq(#host.promote_calls, 0, "no pause promoted after restart clears pause_pending")
end)

-- ── Cycle 11: resize() finishes in-flight tiles immediately ─────────────────

test("resize() snaps in-flight tiles to their destination immediately", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:keypressed("left")
    eq(screen:is_animating(), true, "animating right after the move")
    screen:resize(800, 800)
    for _, t in ipairs(screen:anim_tiles()) do
        eq(t:progress(), 1, "tile snapped to its destination")
    end
    screen:update(0)
    eq(screen:is_animating(), false, "animation cleared on the next update after a resize")
end)

-- ── Cycle 12: tap(x,y) only hit-tests the HUD pause icon ─────────────────────

local function pause_icon_center()
    local tree = hud.hud_tree(0, {})
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            return cmd.x + cmd.w / 2, cmd.y + cmd.h / 2
        end
    end
end

test("tapping the HUD pause icon promotes pause", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local x, y = pause_icon_center()
    screen:tap(x, y)
    eq(#host.promote_calls, 1, "tapping the pause icon promotes pause")
end)

test("tapping elsewhere on the idle board does nothing", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:tap(-100, -100)
    eq(#host.promote_calls, 0, "no pause target outside the icon")
end)

-- ── Cycle 13: mouse/touch swipe queues a move via the screen's own swipe ────

test("a mouse swipe past the threshold queues a move", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:mousepressed(100, 100, 1, false)
    screen:mousemoved(300, 100, 200, 0, false) -- dx=200, well past the 60px threshold
    screen:mousereleased(300, 100, 1, false)
    screen:update(1.0)
    local cells = screen:cells()
    eq(cells[1][3], 2, "tile slid right")
    eq(cells[1][4], 4, "tile slid right")
end)

test("a touch swipe past the threshold queues a move", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:touchpressed(1, 100, 100)
    screen:touchmoved(1, 300, 100)
    screen:touchreleased(1, 300, 100)
    screen:update(1.0)
    local cells = screen:cells()
    eq(cells[1][3], 2, "tile slid right")
    eq(cells[1][4], 4, "tile slid right")
end)

test("a short drag below the threshold resolves as a tap instead of a swipe", function()
    local screen, host = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local x, y = pause_icon_center()
    screen:mousepressed(x, y, 1, false)
    screen:mousereleased(x, y, 1, false)
    eq(#host.promote_calls, 1, "a tap (no movement) on the pause icon promotes pause")
end)

-- ── Cycle 14: resume() recomputes the swipe threshold from window size ──────

test("resume() recomputes the swipe threshold from the current window size", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    local original_dimensions = love.graphics.getDimensions
    love.graphics.getDimensions = function() return 2000, 2000 end -- new threshold: 200px
    screen:resume()
    love.graphics.getDimensions = original_dimensions

    screen:mousepressed(100, 100, 1, false)
    screen:mousemoved(250, 100, 150, 0, false) -- dx=150: above the old 60px threshold, below the new 200px
    screen:mousereleased(250, 100, 1, false)
    screen:update(1.0)

    local cells = screen:cells()
    eq(cells[1][2], 2, "tile unmoved: 150px swipe is below the resumed 200px threshold")
    eq(cells[1][4], 4, "tile unmoved: 150px swipe is below the resumed 200px threshold")
end)

-- ── Cycle 15: draw() composes the board/tile/HUD rendering directly ─────────

test("draw() runs without erroring", function()
    local screen = new_screen({
        {0, 2, 0, 4},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    })
    screen:draw()
    eq(true, true, "no crash")
end)

T.report()
