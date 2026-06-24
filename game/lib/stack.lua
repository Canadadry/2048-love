local M = {}

local function top(self)
    return self._items[#self._items]
end

local function push(self, item)
    local items = self._items
    items[#items + 1] = item
end

local function pop(self)
    local items = self._items
    local n = #items
    assert(n > 0, "stack: pop() called on an empty stack")
    local item = items[n]
    items[n] = nil
    return item
end

local function size(self)
    return #self._items
end

local function for_each(self, fn)
    local items = self._items
    for i = 1, #items do
        fn(items[i])
    end
end

local function rev_for_each(self, fn)
    local items = self._items
    for i = #items, 1, -1 do
        fn(items[i])
    end
end

function M.new(initial)
    return {
        _items = { initial },
        top = top,
        push = push,
        pop = pop,
        size = size,
        for_each = for_each,
        rev_for_each = rev_for_each,
    }
end

return M
