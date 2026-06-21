local config   = require("config")
local settings = require("settings")

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
    love.filesystem.write        = function(path, contents) fs_store[path] = contents; return true end
    love.filesystem.read         = function(path) return fs_store[path] end
    love.filesystem.setIdentity  = function(_) end
end

love.window = { setTitle = function() end, setMode = function() end }
love.graphics.setBackgroundColor = function() end

local function with_restored_config(fn)
    local saved_win_tile = config.WIN_TILE
    local saved_tileset  = config.TILESET
    fn()
    config.WIN_TILE = saved_win_tile
    config.TILESET  = saved_tileset
end

-- ── Tracer bullet ─────────────────────────────────────────────────────────────

test("startup seeds config.WIN_TILE and config.TILESET from saved settings", function()
    with_restored_config(function()
        reset_fs()
        settings.set("win_tile", 32)
        settings.set("theme", "")
        arg = {}
        dofile("main.lua")
        love.load()
        eq(config.WIN_TILE, 32, "config.WIN_TILE seeded from saved settings")
    end)
end)

-- ── CLI flag still wins ───────────────────────────────────────────────────────

test("--win-tile launch flag overrides a saved setting", function()
    with_restored_config(function()
        reset_fs()
        settings.set("win_tile", 2048)
        arg = { "--win-tile=32" }
        dofile("main.lua")
        love.load()
        eq(config.WIN_TILE, 32, "explicit launch flag takes priority over saved settings")
        arg = {}
    end)
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
