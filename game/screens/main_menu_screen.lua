local options_screen = require("screens.options_screen")
local menu           = require("menu")

local M = {}
local Screen = {}

function M.new(host, make_game_screen)
    return setmetatable({ host = host, make_game_screen = make_game_screen }, { __index = Screen })
end

function Screen:enter()
    self._cursor = 0
end

function Screen:cursor()
    return self._cursor
end

local function activate(self, cursor)
    if cursor == 0 then
        self.host:replace(self.make_game_screen())
    elseif cursor == 1 then
        self.host:promote(options_screen.new(self.host))
    elseif cursor == 2 then
        self.host:quit()
    end
end

function Screen:keypressed(key)
    if key == "up" then
        self._cursor = math.max(0, self._cursor - 1)
    elseif key == "down" then
        self._cursor = math.min(2, self._cursor + 1)
    elseif key == "return" then
        activate(self, self._cursor)
    end
end

function Screen:draw()
    menu.draw_main_menu(self._cursor)
end

function Screen:tap(x, y)
    menu.main_menu_hit_test(self._cursor, {
        on_new_game = function() activate(self, 0) end,
        on_options  = function() activate(self, 1) end,
        on_quit     = function() activate(self, 2) end,
    }, x, y)
end

return M
