local check = require("lib.check")

local SM = {}

function SM.new(initial, registry)
    local self = setmetatable({ _current = initial, _registry = registry or {} }, { __index = SM })
    if initial and initial.enter then initial:enter() end
    return self
end

function SM:top()
    return self._current
end

function SM:spawn(name, previous)
    local screen = self._registry[name]
    assert(screen, "screen_manager: no screen registered as '" .. tostring(name) .. "'")
    if previous ~= nil then check.tbl(previous, "previous") end
    return screen.new(self, previous)
end

local function guard_transition(self, fn)
    assert(not self._in_transition, "screen_manager: cannot start a new transition while one is already in progress")
    assert(not self._transition,    "screen_manager: cannot start a new transition while one is already in progress")
    self._in_transition = true
    local ok, err = pcall(fn)
    self._in_transition = false
    if not ok then error(err, 0) end
end

function SM:replace(screen, fn, duration)
    guard_transition(self, function()
        local old = self._current
        if fn and duration then
            local w, h = love.graphics.getDimensions()
            self._transition = {
                out        = old,
                _in        = screen,
                canvas_out = love.graphics.newCanvas(w, h),
                canvas_in  = love.graphics.newCanvas(w, h),
                fn         = fn,
                elapsed    = 0,
                duration   = duration,
            }
            if screen and screen.enter then screen:enter() end
        else
            if old and old.exit then old:exit() end
            self._current = screen
            if screen and screen.enter then screen:enter() end
        end
    end)
end

function SM:is_transitioning()
    return self._transition ~= nil
end

function SM:quit() love.event.quit() end

function SM:update(dt)
    if self._transition then
        local t = self._transition
        if t.out and t.out.update then t.out:update(dt) end
        if t._in and t._in.update then t._in:update(dt) end
        t.elapsed = t.elapsed + dt
        if t.elapsed >= t.duration then
            if t.out and t.out.exit then t.out:exit() end
            self._current = t._in
            self._transition = nil
        end
    else
        if self._current and self._current.update then self._current:update(dt) end
    end
end

function SM:keypressed(k)
    if self._transition then return end
    local top = self._current
    if top and top.keypressed then top:keypressed(k) end
end

function SM:resize(w, h)
    if self._transition then return end
    local top = self._current
    if top and top.resize then top:resize(w, h) end
end

function SM:draw()
    if self._transition then
        local t = self._transition
        local progress = math.min(t.elapsed / t.duration, 1)
        love.graphics.setCanvas(t.canvas_out)
        love.graphics.clear()
        if t.out and t.out.draw then t.out:draw() end
        love.graphics.setCanvas(t.canvas_in)
        love.graphics.clear()
        if t._in and t._in.draw then t._in:draw() end
        love.graphics.setCanvas()
        t.fn(t.canvas_out, t.canvas_in, progress)
    else
        if self._current and self._current.draw then self._current:draw() end
    end
end

return SM
