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

local win_screen = require("screens.win_screen")
local menu       = require("menu")
local config     = require("config")

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

local function stub_host()
    return {
        dismiss_count = 0,
        dismiss       = function(self) self.dismiss_count = self.dismiss_count + 1 end,
    }
end

local function stub_game()
    return {
        restart_count        = 0,
        restart              = function(self) self.restart_count = self.restart_count + 1 end,
        mark_win_seen_count  = 0,
        mark_win_seen        = function(self) self.mark_win_seen_count = self.mark_win_seen_count + 1 end,
    }
end

local function new_screen()
    local host = stub_host()
    local game = stub_game()
    local screen = win_screen.new(host, game)
    screen:enter()
    return screen, host, game
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("Enter at cursor 0 (Continue) marks win seen and dismisses", function()
    local screen, host, game = new_screen()
    screen:keypressed("return")
    eq(game.mark_win_seen_count, 1, "game:mark_win_seen() called")
    eq(host.dismiss_count, 1, "host:dismiss() called")
    eq(game.restart_count, 0, "Continue must not restart")
end)

-- ── Cycle 2: enter() resets cursor to 0 ───────────────────────────────────────

test("cursor starts at 0 (Continue) when entered", function()
    local screen = new_screen()
    eq(screen:cursor(), 0, "cursor starts at 0")
end)

-- ── Cycle 3: up/down move cursor, clamped [0,1] ──────────────────────────────

test("down moves cursor to 1 (Restart)", function()
    local screen = new_screen()
    screen:keypressed("down")
    eq(screen:cursor(), 1, "cursor at 1 after down")
end)

test("down clamps at 1", function()
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 1, "cursor clamped at 1")
end)

test("up moves cursor back to 0 and clamps", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor back to 0")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor clamped at 0")
end)

-- ── Cycle 4: Enter at cursor 1 (Restart) restarts and dismisses ─────────────

test("Enter at cursor 1 (Restart) restarts the game and dismisses", function()
    local screen, host, game = new_screen()
    screen:keypressed("down")
    screen:keypressed("return")
    eq(game.restart_count, 1, "game:restart() called")
    eq(host.dismiss_count, 1, "host:dismiss() called")
    eq(game.mark_win_seen_count, 0, "Restart must not mark win seen")
end)

-- ── Cycle 5: tap(x,y) routes to the same button actions ──────────────────────

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

test("tapping Continue marks win seen and dismisses", function()
    local screen, host, game = new_screen()
    local centers = button_centers(menu.win_tree(screen:cursor(), {}))
    eq(#centers, 2, "expected exactly two buttons")
    screen:tap(centers[1].x, centers[1].y)
    eq(game.mark_win_seen_count, 1, "game:mark_win_seen() called")
    eq(host.dismiss_count, 1, "host:dismiss() called")
end)

test("tapping Restart restarts the game and dismisses", function()
    local screen, host, game = new_screen()
    local centers = button_centers(menu.win_tree(screen:cursor(), {}))
    screen:tap(centers[2].x, centers[2].y)
    eq(game.restart_count, 1, "game:restart() called")
    eq(host.dismiss_count, 1, "host:dismiss() called")
end)

test("tapping outside any button does nothing", function()
    local screen, host, game = new_screen()
    screen:tap(-100, -100)
    eq(host.dismiss_count, 0, "no dismiss on a miss")
    eq(game.restart_count, 0, "no restart on a miss")
    eq(game.mark_win_seen_count, 0, "no mark_win_seen on a miss")
end)

-- ── Cycle 6: draw() delegates to menu.draw_win ───────────────────────────────

test("draw() runs without erroring", function()
    local screen = new_screen()
    screen:draw()
    eq(true, true, "no crash")
end)

-- ── Cycle 7: opaque() returns false ──────────────────────────────────────────

test("opaque() is false so the board beneath stays visible", function()
    local screen = new_screen()
    eq(screen:opaque(), false, "win screen must be a translucent overlay")
end)

-- ── Cycle 8: enter() spawns particles per config.EFFECTS_ENABLED ─────────────

test("entering with effects enabled populates win_particles in range", function()
    local screen = new_screen()
    local n = #screen:win_particles()
    if n < config.PARTICLE_COUNT_MIN or n > config.PARTICLE_COUNT_MAX then
        error("win_particles count out of range: " .. n)
    end
end)

test("entering with effects disabled leaves win_particles empty", function()
    config.EFFECTS_ENABLED = false
    local screen = new_screen()
    eq(#screen:win_particles(), 0, "no particles spawned when effects are disabled")
    config.EFFECTS_ENABLED = true
end)

-- ── Cycle 9: update(dt) culls dead particles individually ────────────────────

test("particles individually disappear as their lifetimes expire, not all at once", function()
    local screen = new_screen()
    local initial = #screen:win_particles()
    if initial == 0 then error("expected particles to spawn on enter") end
    local saw_partial_drop = false
    for _ = 1, 30 do
        screen:update(0.1)
        local n = #screen:win_particles()
        if n > 0 and n < initial then saw_partial_drop = true end
        if n == 0 then break end
    end
    eq(saw_partial_drop, true, "particle count should drop gradually, not all at once")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
