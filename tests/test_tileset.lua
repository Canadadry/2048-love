local tileset = require("tileset")

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

-- Tracer bullet: parse_meta extracts tile_w from sidecar table
test("parse_meta returns tile_w", function()
    local meta = tileset.parse_meta({ tile_width = 64, tile_height = 48, frame_counts = { 4, 2 } })
    eq(meta.tile_w, 64, "tile_w")
end)

test("parse_meta returns tile_h", function()
    local meta = tileset.parse_meta({ tile_width = 64, tile_height = 48, frame_counts = { 4, 2 } })
    eq(meta.tile_h, 48, "tile_h")
end)

test("parse_meta returns frame_counts", function()
    local meta = tileset.parse_meta({ tile_width = 64, tile_height = 48, frame_counts = { 4, 2, 8 } })
    eq(meta.frame_counts[1], 4, "frame_counts[1]")
    eq(meta.frame_counts[2], 2, "frame_counts[2]")
    eq(meta.frame_counts[3], 8, "frame_counts[3]")
end)

test("value_to_row(2) returns 1", function()
    eq(tileset.value_to_row(2), 1, "row for value 2")
end)

test("value_to_row(2048) returns 11", function()
    eq(tileset.value_to_row(2048), 11, "row for value 2048")
end)

test("value_to_row returns nil for non-power-of-2", function()
    eq(tileset.value_to_row(3),  nil, "3 is not a power of 2")
    eq(tileset.value_to_row(0),  nil, "0 is not a valid tile")
    eq(tileset.value_to_row(1),  nil, "1 is not a valid tile")
end)

-- frame_at: returns frame index for a given time
test("frame_at returns 0 at time 0", function()
    eq(tileset.frame_at(4, 8, 0.0), 0, "frame at t=0")
end)

test("frame_at returns 1 at one frame interval", function()
    eq(tileset.frame_at(4, 8, 1/8), 1, "frame at t=1/fps")
end)

test("frame_at wraps to 0 after a full cycle", function()
    -- 4 frames at 8fps: cycle period = 4/8 = 0.5s
    eq(tileset.frame_at(4, 8, 0.5), 0, "wrap after full cycle")
end)

test("frame_at single-frame tile always returns 0", function()
    eq(tileset.frame_at(1, 8, 999), 0, "single frame never changes")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
