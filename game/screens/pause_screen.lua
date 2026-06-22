local menu = require("menu")

local M = {}
local Screen = {}

local function hit(btn, x, y)
    return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
end

function M.new(host, game, make_main_menu)
    return setmetatable({ host = host, game = game, make_main_menu = make_main_menu }, { __index = Screen })
end

function Screen:enter()
    self._cursor = 0
end

function Screen:pause_cursor()
    return self._cursor
end

function Screen:draw()
    menu.draw_pause(self._cursor)
end

function Screen:opaque()
    return false
end

local function activate(self, cursor)
    if cursor == 0 then
        self.host:dismiss()
    elseif cursor == 1 then
        self.game:restart()
        self.host:dismiss()
    elseif cursor == 2 then
        self.host:replace(self.make_main_menu())
    elseif cursor == 3 then
        self.host:quit()
    end
end

function Screen:keypressed(key)
    if key == "up" then
        self._cursor = math.max(0, self._cursor - 1)
    elseif key == "down" then
        self._cursor = math.min(3, self._cursor + 1)
    elseif key == "escape" then
        self.host:dismiss()
    elseif key == "return" then
        activate(self, self._cursor)
    end
end

function Screen:tap(x, y)
    for i, btn in ipairs(menu.pause_button_bounds()) do
        if hit(btn, x, y) then
            activate(self, i - 1)
            return
        end
    end
end

return M
