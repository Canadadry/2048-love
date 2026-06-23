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

return M
