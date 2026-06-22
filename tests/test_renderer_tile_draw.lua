local tile_draw = require("renderer.tile_draw")

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

-- Tracer bullet: tile_color returns the configured color for a known value
test("tile_color returns config color for a known value", function()
    local config = require("config")
    local colors = tile_draw.tile_color(2)
    eq(colors, config.TILE_COLORS[2], "colors for value 2")
end)

test("tile_color falls back to default color for an unknown value", function()
    local config = require("config")
    local colors = tile_draw.tile_color(99999)
    eq(colors, config.DEFAULT_TILE_COLOR, "colors for unknown value")
end)

test("needs_reload is false when requested name matches loaded name", function()
    eq(tile_draw.needs_reload("classic", "classic"), false, "same name")
end)

test("needs_reload is true when requested name differs from loaded name", function()
    eq(tile_draw.needs_reload("jurassic-park", "classic"), true, "different name")
end)

test("needs_reload is true on the first-ever call, even when requesting the empty/classic theme", function()
    eq(tile_draw.needs_reload("", tile_draw.NOT_LOADED), true, "first call with empty name")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
