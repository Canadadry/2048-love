local check = require("lib.check")

-- Must not end in .lua: LÖVE's save directory shadows the source directory
-- on read, so a same-named save file would hide this very module on require().
local SAVE_FILE = "settings.dat"

local M = {}
local _data = {}

local function serialize(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        local val = type(v) == "string" and string.format("%q", v) or tostring(v)
        parts[#parts + 1] = string.format("[%q] = %s", k, val)
    end
    return "return {\n    " .. table.concat(parts, ",\n    ") .. "\n}\n"
end

function M.get(key, default)
    check.str(key, "key")
    local v = _data[key]
    if v == nil then return default end
    return v
end

function M.set(key, value)
    check.str(key, "key")
    _data[key] = value
    M.save()
end

function M.save()
    local ok, err = love.filesystem.write(SAVE_FILE, serialize(_data))
    assert(ok, "failed to write settings: " .. tostring(err))
end

function M.load()
    _data = {}
    local contents = love.filesystem.read(SAVE_FILE)
    if not contents then return end
    local chunk = load(contents, SAVE_FILE, "t", {})
    if not chunk then return end
    local ok, result = pcall(chunk)
    if ok and type(result) == "table" then
        _data = result
    end
end

return M
