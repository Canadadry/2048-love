local settings = require("lib.settings")

local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("PASS " .. name)
        pass = pass + 1
    else
        print("FAIL " .. name)
        print("     " .. tostring(err))
        fail = fail + 1
    end
end

local function eq(a, b, msg)
    if a ~= b then
        error((msg or "eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

local fs_store

local function reset_fs()
    fs_store = {}
    love.filesystem.write = function(path, contents) fs_store[path] = contents; return true end
    love.filesystem.read  = function(path) return fs_store[path] end
end

-- ── Tracer bullet ─────────────────────────────────────────────────────────────

test("save() then load() on a fresh state round-trips a value", function()
    reset_fs()
    settings.set("win_tile", 32)
    settings.load()
    eq(settings.get("win_tile", 2048), 32, "win_tile persisted across save/load")
end)

-- ── Missing / corrupt file ───────────────────────────────────────────────────

test("load() with no settings file leaves defaults intact", function()
    reset_fs()
    settings.load()
    eq(settings.get("win_tile", 2048), 2048, "default returned when nothing was ever saved")
end)

test("load() with a corrupt settings file falls back to defaults without crashing", function()
    reset_fs()
    fs_store["settings.lua"] = "this is not { valid lua >>>"
    settings.load()
    eq(settings.get("win_tile", 2048), 2048, "default returned when file is corrupt")
end)

-- ── Save path must not shadow the module on require() ───────────────────────

test("save() never writes to a path ending in .lua (would shadow this module via LÖVE's save-dir precedence on require)", function()
    reset_fs()
    settings.set("win_tile", 32)
    for path in pairs(fs_store) do
        if path:match("%.lua$") then
            error("settings save file must not end in .lua, got " .. path)
        end
    end
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
