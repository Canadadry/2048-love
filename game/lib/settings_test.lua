local settings = require("lib.settings")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

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

T.report()
