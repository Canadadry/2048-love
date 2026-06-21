local check = require("check")

local M = {}
local Model = {}
Model.__index = Model

function M.new(rows)
    check.tbl(rows, "rows")
    assert(#rows > 0, "rows must be a non-empty list")
    local value_indices = {}
    for i, row in ipairs(rows) do
        check.tbl(row.values, "rows[" .. i .. "].values")
        assert(#row.values > 0, "rows[" .. i .. "].values must be a non-empty list")
        value_indices[i] = row.value_index or 1
    end
    return setmetatable({
        _rows = rows,
        _value_indices = value_indices,
        _focused_row = 1,
    }, Model)
end

function Model:focused_row()
    return self._focused_row
end

function Model:up()
    self._focused_row = (self._focused_row - 2) % #self._rows + 1
end

function Model:down()
    self._focused_row = self._focused_row % #self._rows + 1
end

function Model:left()
    local i = self._focused_row
    local n = #self._rows[i].values
    self._value_indices[i] = (self._value_indices[i] - 2) % n + 1
end

function Model:right()
    local i = self._focused_row
    local n = #self._rows[i].values
    self._value_indices[i] = self._value_indices[i] % n + 1
end

function Model:row_value(i)
    local row = self._rows[i]
    return row.values[self._value_indices[i]]
end

return M
