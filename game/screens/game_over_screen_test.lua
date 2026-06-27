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

local game_over_screen = require("screens.game_over_screen")
local menu              = require("menu")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local function stub_host(main_menu_screen)
    return {
        replace_calls = {},
        replace       = function(self, screen) table.insert(self.replace_calls, screen) end,
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
    local screen = game_over_screen.new(host, game)
    screen:enter()
    return screen, host, game, main_menu_screen
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("Enter restarts the game and calls host:replace() with the game screen", function()
    local screen, host, game = new_screen()
    screen:keypressed("return")
    eq(game.restart_count, 1, "game:restart() called")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game, "replaced with the game screen")
end)

-- ── Cycle 2: any arrow key also restarts ─────────────────────────────────────

for _, key in ipairs({ "left", "right", "up", "down" }) do
    test("arrow key '" .. key .. "' restarts the game and calls host:replace() with the game screen", function()
        local screen, host, game = new_screen()
        screen:keypressed(key)
        eq(game.restart_count, 1, "game:restart() called")
        eq(#host.replace_calls, 1, "host:replace() called once")
        eq(host.replace_calls[1], game, "replaced with the game screen")
    end)
end

-- ── Cycle 3: tapping the New Game button restarts ────────────────────────────

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

test("tapping the New Game button restarts and calls host:replace() with the game screen", function()
    local screen, host, game = new_screen()
    local centers = button_centers(menu.menu_tree(screen:spec(), -1, nil))
    eq(#centers, 2, "expected exactly two buttons")
    screen:tap(centers[1].x, centers[1].y)
    eq(game.restart_count, 1, "game:restart() called")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], game, "replaced with the game screen")
end)

-- ── Cycle 4: tapping the Main Menu button replaces with main menu ────────────

test("tapping the Main Menu button calls host:replace() with the main menu screen", function()
    local screen, host, _, main_menu_screen = new_screen()
    local centers = button_centers(menu.menu_tree(screen:spec(), -1, nil))
    screen:tap(centers[2].x, centers[2].y)
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], main_menu_screen, "replaced with the main menu screen")
end)

-- ── Cycle 5: tapping outside the button does nothing ────────────────────────

test("tapping outside the buttons does nothing", function()
    local screen, host, game = new_screen()
    screen:tap(-100, -100)
    eq(game.restart_count, 0, "no restart on a miss")
    eq(#host.replace_calls, 0, "no replace on a miss")
end)

-- ── Cycle 6: draw() delegates to menu.draw_game_over ─────────────────────────

test("draw() runs without erroring", function()
    local screen = new_screen()
    screen:draw()
    eq(true, true, "no crash")
end)

T.report()
