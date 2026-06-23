local check = require("lib.check")

local M = {}
local Mixin = {}

function M.new(config)
    check.tbl(config, "config")
    check.tbl(config.items, "config.items")
    assert(#config.items > 0, "config.items must be a non-empty list")
    return setmetatable({
        _items        = config.items,
        _wrap         = config.wrap or false,
        _cursor_start = config.cursor_start or 0,
        _cursor       = config.cursor_start or 0,
    }, { __index = Mixin })
end

function Mixin:cursor()
    return self._cursor
end

function Mixin:items()
    return self._items
end

function Mixin:enter()
    self._cursor = self._cursor_start
end

local function step(self, dir)
    local items = self._items
    local n     = #items
    local i     = self._cursor + 1
    while true do
        local ni = i + dir
        if ni < 1 or ni > n then
            if not self._wrap then return i end
            ni = (ni - 1) % n + 1
        end
        i = ni
        if items[i].focusable ~= false then return i end
    end
end

function Mixin:current_item()
    return self._items[self._cursor + 1]
end

function Mixin:keypressed(key)
    if key == "down" then
        self._cursor = step(self, 1) - 1
    elseif key == "up" then
        self._cursor = step(self, -1) - 1
    elseif key == "return" then
        local item = self:current_item()
        if item.on_activate then item.on_activate() end
    elseif key == "left" then
        local item = self:current_item()
        if item.on_left then item.on_left() end
    elseif key == "right" then
        local item = self:current_item()
        if item.on_right then item.on_right() end
    end
end

function Mixin:tap(i)
    local item = self._items[i]
    if not item or item.focusable == false then return end
    local focus_first = item.value ~= nil or item.focus_before_activate
    if focus_first and self._cursor + 1 ~= i then
        self._cursor = i - 1
    elseif item.value ~= nil then
        if item.on_right then item.on_right() end
    elseif item.on_activate then
        item.on_activate()
    end
end

return M
