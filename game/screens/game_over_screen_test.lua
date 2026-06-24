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
    return { restart_count = 0, restart = function(self) self.restart_count = self.restart_count + 1 end }
end

local function new_screen()
    local host = stub_host()
    local game = stub_game()
    local screen = game_over_screen.new(host, game)
    return screen, host, game
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("Enter restarts the game and dismisses the game over screen", function()
    local screen, host, game = new_screen()
    screen:keypressed("return")
    eq(game.restart_count, 1, "game:restart() called")
    eq(host.dismiss_count, 1, "host:dismiss() called")
end)

-- ── Cycle 2: any arrow key also restarts ─────────────────────────────────────

for _, key in ipairs({ "left", "right", "up", "down" }) do
    test("arrow key '" .. key .. "' restarts the game and dismisses", function()
        local screen, host, game = new_screen()
        screen:keypressed(key)
        eq(game.restart_count, 1, "game:restart() called")
        eq(host.dismiss_count, 1, "host:dismiss() called")
    end)
end

-- ── Cycle 3: tapping the Restart button restarts ────────────────────────────

local function button_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and cmd.painter.kind == "Group" then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

test("tapping the Restart button restarts the game and dismisses", function()
    local screen, host, game = new_screen()
    local centers = button_centers(menu.menu_tree(screen:spec(), -1, nil))
    eq(#centers, 1, "expected exactly one button")
    screen:tap(centers[1].x, centers[1].y)
    eq(game.restart_count, 1, "game:restart() called")
    eq(host.dismiss_count, 1, "host:dismiss() called")
end)

-- ── Cycle 4: tapping outside the button does nothing ────────────────────────

test("tapping outside the Restart button does nothing", function()
    local screen, host, game = new_screen()
    screen:tap(-100, -100)
    eq(game.restart_count, 0, "no restart on a miss")
    eq(host.dismiss_count, 0, "no dismiss on a miss")
end)

-- ── Cycle 5: draw() delegates to menu.draw_game_over ─────────────────────────

test("draw() runs without erroring", function()
    local screen = new_screen()
    screen:draw()
    eq(true, true, "no crash")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
