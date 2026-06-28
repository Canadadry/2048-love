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
        print     = function(...) end,
        print     = function(...) end,
        setFont   = function(...) end,
    },
}

local main_menu_screen = require("screens.main_menu_screen")
local menu             = require("menu")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local function stub_host(spawned)
    return {
        replace_calls = {},
        replace       = function(self, screen) table.insert(self.replace_calls, screen) end,
        quit_count    = 0,
        quit          = function(self) self.quit_count = self.quit_count + 1 end,
        spawn         = function(self, name) return spawned[name] end,
    }
end

local function new_screen()
    local game_screen_sentinel = { sentinel = true }
    local options_screen_sentinel = { sentinel = "options" }
    local host = stub_host({ loading = game_screen_sentinel, game = game_screen_sentinel, options = options_screen_sentinel })
    local screen = main_menu_screen.new(host)
    screen:enter()
    return screen, host, game_screen_sentinel
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("cursor starts at 0 when entered", function()
    local screen = new_screen()
    eq(screen:cursor(), 0, "cursor starts at 0 (New Game)")
end)

-- ── Cycle 2: up/down move cursor, clamped [0,2] ──────────────────────────────

test("cursor moves down with down key", function()
    local screen = new_screen()
    screen:keypressed("down")
    eq(screen:cursor(), 1, "cursor at 1 after down")
end)

test("cursor clamps at 2", function()
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 2, "cursor clamped at 2")
end)

test("cursor moves up and clamps at 0", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor back to 0")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor clamped at 0")
end)

-- ── Cycle 3: return at cursor=0 (New Game) calls host:replace() ─────────────

test("return with cursor=0 (New Game) calls host:replace() with a fresh game screen", function()
    local screen, host, game_screen_sentinel = new_screen()
    screen:keypressed("return")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game_screen_sentinel, "replaced with the screen from make_game_screen()")
end)

-- ── Cycle 4: return at cursor=1 (Options) calls host:replace() ──────────────

test("return with cursor=1 (Options) calls host:replace() with an options screen", function()
    local screen, host = new_screen()
    screen:keypressed("down")
    screen:keypressed("return")
    eq(#host.replace_calls, 1, "host:replace() called once")
end)

-- ── Cycle 5: return at cursor=2 (Quit) calls host:quit() ────────────────────

test("return with cursor=2 (Quit) calls host:quit()", function()
    local screen, host = new_screen()
    screen:keypressed("down"); screen:keypressed("down")
    screen:keypressed("return")
    eq(host.quit_count, 1, "host:quit() called")
end)

-- ── Cycle 6: tap(x,y) routes to the same action dispatch ─────────────────────

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

test("tapping New Game activates index 0 even if cursor was elsewhere", function()
    local screen, host, game_screen_sentinel = new_screen()
    screen:keypressed("down"); screen:keypressed("down")
    local centers = button_centers(menu.menu_tree(screen:spec(), 0, nil))
    screen:tap(centers[1].x, centers[1].y)
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game_screen_sentinel, "tap on New Game replaced with make_game_screen() result")
end)

test("tapping Options calls host:replace()", function()
    local screen, host = new_screen()
    local centers = button_centers(menu.menu_tree(screen:spec(), 0, nil))
    screen:tap(centers[2].x, centers[2].y)
    eq(#host.replace_calls, 1, "host:replace() called once")
end)

test("tapping Quit calls host:quit()", function()
    local screen, host = new_screen()
    local centers = button_centers(menu.menu_tree(screen:spec(), 0, nil))
    screen:tap(centers[3].x, centers[3].y)
    eq(host.quit_count, 1, "host:quit() called")
end)

test("tapping outside any button does nothing", function()
    local screen, host = new_screen()
    screen:tap(-100, -100)
    eq(#host.replace_calls, 0, "no replace on a miss")
    eq(host.quit_count, 0, "no quit on a miss")
end)

-- ── Cycle 8: keys unrelated to menu nav are no-ops ───────────────────────────

test("unrelated keys do not move the cursor or fire any action", function()
    local screen, host = new_screen()
    screen:keypressed("left")
    screen:keypressed("escape")
    eq(screen:cursor(), 0, "cursor unchanged")
    eq(#host.replace_calls, 0, "no replace")
    eq(host.quit_count, 0, "no quit")
end)

-- ── Cycle 9: draw() delegates to menu.draw_main_menu ─────────────────────────

test("draw() runs without erroring", function()
    local screen = new_screen()
    screen:draw()
    eq(true, true, "no crash")
end)

T.report()
