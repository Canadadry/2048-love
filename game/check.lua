local M = {}

function M.num(v, name)
    assert(type(v) == "number",
        (name or "value") .. " must be number, got " .. type(v))
end

function M.str(v, name)
    assert(type(v) == "string",
        (name or "value") .. " must be string, got " .. type(v))
end

function M.tbl(v, name)
    assert(type(v) == "table",
        (name or "value") .. " must be table, got " .. type(v))
end

function M.bool(v, name)
    assert(type(v) == "boolean",
        (name or "value") .. " must be boolean, got " .. type(v))
end

function M.range(v, lo, hi, name)
    assert(type(v) == "number" and v >= lo and v <= hi,
        string.format("%s must be in [%s, %s], got %s",
            name or "value", tostring(lo), tostring(hi), tostring(v)))
end

function M.one_of(v, set, name)
    assert(set[v] ~= nil,
        (name or "value") .. " has invalid value: " .. tostring(v))
end

local function is_valid_cell(v)
    if v == 0 then return true end
    if type(v) ~= "number" or v < 2 then return false end
    local n = v
    while n > 1 do
        if n % 2 ~= 0 then return false end
        n = n / 2
    end
    return true
end

function M.grid_cells(cells, size, name)
    local label = name or "cells"
    assert(type(cells) == "table", label .. " must be a table")
    assert(#cells == size,
        string.format("%s must have %d rows, got %d", label, size, #cells))
    for r = 1, size do
        assert(type(cells[r]) == "table",
            string.format("%s[%d] must be a table", label, r))
        assert(#cells[r] == size,
            string.format("%s[%d] must have %d cols, got %d", label, r, size, #cells[r]))
        for c = 1, size do
            assert(is_valid_cell(cells[r][c]),
                string.format("%s[%d][%d] must be 0 or power of 2, got %s",
                    label, r, c, tostring(cells[r][c])))
        end
    end
end

return M
