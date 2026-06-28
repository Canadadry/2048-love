love = {
    filesystem = {
        getDirectoryItems = function(_) return {} end,
    },
}

local bg_picker = require("lib.bg_picker")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local function approx(a, b, msg)
    if math.abs(a - b) > 1e-9 then
        error((msg or "approx") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

-- ── Cycle 1: Tracer bullet — square image, square screen, zoom=1.0 ────────────

test("fit_cover: square image on square screen zoom=1.0 fills exactly", function()
    local x, y, scale = bg_picker.fit_cover(100, 100, 200, 200, 1.0)
    approx(scale, 2.0, "scale")
    approx(x,     0.0, "x")
    approx(y,     0.0, "y")
end)

-- ── Cycle 2: zoom > 1.0 overscales the image ────────────────────────────────

test("fit_cover: zoom=1.1 enlarges image 10% beyond fill", function()
    local x, y, scale = bg_picker.fit_cover(100, 100, 200, 200, 1.1)
    approx(scale, 2.2,  "scale")
    approx(x,     -10,  "x is negative — image bleeds past left edge")
    approx(y,     -10,  "y is negative — image bleeds past top edge")
end)

-- ── Cycle 3: wide image on tall screen — scale from height, no black bars ────

test("fit_cover: wide image on tall screen picks the larger scale axis", function()
    -- image 200×100, screen 100×200 — need scale 2 from height axis (200/100=2 vs 100/200=0.5)
    local x, y, scale = bg_picker.fit_cover(200, 100, 100, 200, 1.0)
    approx(scale, 2.0,   "scale driven by height axis")
    approx(x,     -150,  "x: image bleeds left (400px wide − 100px screen = 300px overflow, split)")
    approx(y,     0.0,   "y: image fits height exactly")
end)

-- ── Cycle 4: pick returns a path when PNGs exist ─────────────────────────────

test("pick: returns a path from the directory when PNGs are present", function()
    love.filesystem.getDirectoryItems = function(_) return { "a.png", "b.png", "c.png" } end
    local fixed_rand = function(_) return 1 end   -- always picks index 1
    local path = bg_picker.pick("assets/Bg", fixed_rand)
    eq(path, "assets/Bg/a.png", "first file selected")
end)

test("pick: returns nil when the directory has no PNG files", function()
    love.filesystem.getDirectoryItems = function(_) return { "readme.txt" } end
    local path = bg_picker.pick("assets/Bg")
    eq(path, nil, "nil when no PNGs")
end)

test("pick: returns nil when the directory is empty", function()
    love.filesystem.getDirectoryItems = function(_) return {} end
    local path = bg_picker.pick("assets/Bg")
    eq(path, nil, "nil when directory is empty")
end)

T.report()
