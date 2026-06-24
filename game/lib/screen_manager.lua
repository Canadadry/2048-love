local check = require("lib.check")
local stack = require("lib.stack")

local SM = {}

function SM.new(initial, registry)
    local self = setmetatable({ _stack = stack.new(initial), _registry = registry or {} }, { __index = SM })
    if initial and initial.enter then initial:enter() end
    return self
end

function SM:top()
    return self._stack:top()
end

function SM:spawn(name, previous)
    local screen = self._registry[name]
    assert(screen, "screen_manager: no screen registered as '" .. tostring(name) .. "'")
    if previous ~= nil then check.tbl(previous, "previous") end
    return screen.new(self, previous)
end

local function guard_transition(self, fn)
    assert(not self._in_transition, "screen_manager: cannot start a new transition while one is already in progress")
    self._in_transition = true
    local ok, err = pcall(fn)
    self._in_transition = false
    if not ok then error(err, 0) end
end

function SM:promote(screen)
    guard_transition(self, function()
        local old_top = self._stack:top()
        if old_top and old_top.pause then old_top:pause() end
        self._stack:push(screen)
        if screen and screen.enter then screen:enter() end
    end)
end

function SM:dismiss()
    guard_transition(self, function()
        assert(self._stack:size() > 1, "dismiss() called with nothing left on the stack to dismiss to")
        local top = self._stack:pop()
        if top and top.exit then top:exit() end
        local new_top = self._stack:top()
        if new_top and new_top.resume then new_top:resume() end
    end)
end

function SM:replace(screen)
    guard_transition(self, function()
        local s = self._stack
        while s:size() > 0 do
            local removed = s:pop()
            if removed and removed.exit then removed:exit() end
        end
        s:push(screen)
        if screen and screen.enter then screen:enter() end
    end)
end

function SM:quit() love.event.quit() end

function SM:update(dt)
    self._stack:rev_for_each(function(x)
        if x and x.update then x:update(dt) end
    end)
end

function SM:keypressed(k)
    local top = self._stack:top()
    if top and top.keypressed then top:keypressed(k) end
end

function SM:resize(w, h)
    local top = self._stack:top()
    if top and top.resize then top:resize(w, h) end
end

function SM:draw()
    self._stack:for_each(function(x)
        if x and x.draw then x:draw() end
    end)
end

return SM
