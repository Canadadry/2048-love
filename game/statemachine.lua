local M  = {}
local SM = {}

local mt = {
    __index = function(t, k)
        local own = rawget(SM, k)
        if own ~= nil then return own end
        local active = rawget(t, "_active")
        if active then
            local m = active[k]
            if type(m) == "function" then
                return function(_, ...) return m(active, ...) end
            end
            return m
        end
    end
}

function M.new(initial)
    local self = setmetatable({ _active = initial }, mt)
    if initial and initial.enter then initial:enter() end
    return self
end

function SM:switch(next)
    local a = self._active
    if a and a.exit then a:exit() end
    self._active = next
    if next and next.enter then next:enter() end
end

local function dispatch(self, method, ...)
    local a = self._active
    if a and a[method] then a[method](a, ...) end
end

function SM:update(dt)    dispatch(self, "update", dt) end
function SM:keypressed(k) dispatch(self, "keypressed", k) end
function SM:draw()        dispatch(self, "draw") end
function SM:resize(w, h)  dispatch(self, "resize", w, h) end

return M
