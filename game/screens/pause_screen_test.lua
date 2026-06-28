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

local pause_screen = require("screens.pause_screen")
local menu         = require("menu")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local function stub_host(main_menu_screen)
    return {
        replace_calls = {},
        replace       = function(self, screen) table.insert(self.replace_calls, screen) end,
        quit_count    = 0,
        quit          = function(self) self.quit_count = self.quit_count + 1 end,
        spawn         = function(self, name) if name == "main_menu" then return main_menu_screen end end,
    }
end

local function stub_game()
    return { restart_count = 0, restart = function(self) self.restart_count = self.restart_count + 1 end }
end

local function new_screen()
    local main_menu_screen = { sentinel = true }
    local host = stub_host(main_menu_screen)
    local game = stub_game()
    local screen = pause_screen.new(host, game)
    screen:enter()
    return screen, host, game, main_menu_screen
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("escape calls host:replace() with the game screen", function()
    local screen, host, game = new_screen()
    screen:keypressed("escape")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game, "replaced with the game screen")
end)

-- ── Cycle 2: enter() resets cursor to 0 ───────────────────────────────────────

test("cursor starts at 0 when entered", function()
    local screen = new_screen()
    eq(screen:cursor(), 0, "cursor starts at 0 (Resume)")
end)

-- ── Cycle 3: up/down move cursor, clamped [0,3] ──────────────────────────────

test("cursor moves down with down key", function()
    local screen = new_screen()
    screen:keypressed("down")
    eq(screen:cursor(), 1, "cursor at 1 after down")
    screen:keypressed("down")
    eq(screen:cursor(), 2, "cursor at 2 after second down")
end)

test("cursor clamps at 3", function()
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 3, "cursor clamped at 3")
end)

test("cursor moves up and clamps at 0", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor back to 0")
    screen:keypressed("up")
    eq(screen:cursor(), 0, "cursor clamped at 0")
end)

-- ── Cycle 4: return at cursor=0 (Resume) replaces with game ─────────────────

test("return with cursor=0 (Resume) calls host:replace() with the game screen", function()
    local screen, host, game = new_screen()
    screen:keypressed("return")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game, "replaced with the game screen")
end)

-- ── Cycle 5: return at cursor=1 (New Game) restarts and replaces ─────────────

test("return with cursor=1 (New Game) restarts the game and calls host:replace() with the game screen", function()
    local screen, host, game = new_screen()
    screen:keypressed("down")
    screen:keypressed("return")
    eq(game.restart_count, 1, "game:restart() called")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game, "replaced with the game screen")
end)

-- ── Cycle 6: return at cursor=2 (Main Menu) replaces stack ───────────────────

test("return with cursor=2 (Main Menu) calls host:replace() with the main menu screen", function()
    local screen, host, _, main_menu_screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down")
    screen:keypressed("return")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], main_menu_screen, "replaced with the screen from make_main_menu()")
end)

-- ── Cycle 7: return at cursor=3 (Quit) calls host:quit() ────────────────────

test("return with cursor=3 (Quit) calls host:quit()", function()
    local screen, host = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    screen:keypressed("return")
    eq(host.quit_count, 1, "host:quit() called")
end)

-- ── Cycle 8: tap(x,y) routes to the same button actions ──────────────────────

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

local function button_center(screen, i)
    local centers = button_centers(menu.menu_tree(screen:spec(), screen:cursor(), nil))
    return centers[i].x, centers[i].y
end

test("tapping the Resume button calls host:replace() with the game screen", function()
    local screen, host, game = new_screen()
    local x, y = button_center(screen, 1)
    screen:tap(x, y)
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game, "replaced with the game screen")
end)

test("tapping the New Game button restarts and calls host:replace() with the game screen", function()
    local screen, host, game = new_screen()
    local x, y = button_center(screen, 2)
    screen:tap(x, y)
    eq(game.restart_count, 1, "New Game button restarts")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game, "replaced with the game screen")
end)

test("tapping the Main Menu button calls host:replace()", function()
    local screen, host, _, main_menu_screen = new_screen()
    local x, y = button_center(screen, 3)
    screen:tap(x, y)
    eq(host.replace_calls[1], main_menu_screen, "Main Menu button replaces with the main menu screen")
end)

test("tapping the Quit button calls host:quit()", function()
    local screen, host = new_screen()
    local x, y = button_center(screen, 4)
    screen:tap(x, y)
    eq(host.quit_count, 1, "Quit button calls host:quit()")
end)

test("tapping outside any button does nothing", function()
    local screen, host, game = new_screen()
    screen:tap(-100, -100)
    eq(#host.replace_calls, 0, "no replace on a miss")
    eq(game.restart_count, 0, "no restart on a miss")
    eq(host.quit_count, 0, "no quit on a miss")
end)

-- ── Cycle 9: draw() delegates to menu.draw_pause ─────────────────────────────

test("draw() runs without erroring", function()
    local screen = new_screen()
    screen:draw()
    eq(true, true, "no crash")
end)

T.report()
