local M  = {}
local SM = {}

local mt = {
    __index = function(t, k)
        local own = rawget(SM, k)
        if own ~= nil then return own end
        local stack = rawget(t, "_stack")
        local top = stack and stack[#stack]
        if top then
            local m = top[k]
            if type(m) == "function" then
                return function(_, ...) return m(top, ...) end
            end
            return m
        end
    end
}

function M.new(initial)
    local self = setmetatable({ _stack = { initial } }, mt)
    if initial and initial.enter then initial:enter() end
    return self
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
        local old_top = self._stack[#self._stack]
        if old_top and old_top.pause then old_top:pause() end
        self._stack[#self._stack + 1] = screen
        if screen and screen.enter then screen:enter() end
    end)
end

function SM:dismiss()
    guard_transition(self, function()
        local stack = self._stack
        assert(#stack > 1, "dismiss() called with nothing left on the stack to dismiss to")
        local top = stack[#stack]
        stack[#stack] = nil
        if top and top.exit then top:exit() end
        local new_top = stack[#stack]
        if new_top and new_top.resume then new_top:resume() end
    end)
end

function SM:replace(screen)
    guard_transition(self, function()
        local stack = self._stack
        for i = #stack, 1, -1 do
            local s = stack[i]
            if s and s.exit then s:exit() end
            stack[i] = nil
        end
        stack[1] = screen
        if screen and screen.enter then screen:enter() end
    end)
end

local function dispatch(self, method, ...)
    local stack = self._stack
    local top = stack[#stack]
    if top and top[method] then return top[method](top, ...) end
end

function SM:quit() love.event.quit() end

function SM:update(dt)    dispatch(self, "update", dt) end
function SM:keypressed(k) dispatch(self, "keypressed", k) end
function SM:resize(w, h)  dispatch(self, "resize", w, h) end

function SM:draw()
    local stack = self._stack
    local start = #stack
    for i = #stack, 1, -1 do
        local s = stack[i]
        local is_opaque = not (s and s.opaque) or s:opaque()
        if is_opaque then
            start = i
            break
        end
    end
    for i = start, #stack do
        local s = stack[i]
        if s and s.draw then s:draw() end
    end
end

return M
