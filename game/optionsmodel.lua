local check = require("check")

local M = {}

local function index_of(values, value)
    for i, v in ipairs(values) do
        if v == value then return i end
    end
    return 1
end

function M.next(values, value)
    check.tbl(values, "values")
    assert(#values > 0, "values must be a non-empty list")
    local i = index_of(values, value)
    return values[i % #values + 1]
end

function M.prev(values, value)
    check.tbl(values, "values")
    assert(#values > 0, "values must be a non-empty list")
    local i = index_of(values, value)
    return values[(i - 2) % #values + 1]
end

return M
