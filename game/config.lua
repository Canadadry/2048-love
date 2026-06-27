local tween          = require("lib.tween")
local M              = {}

M.GRID_SIZE          = 4
M.WINDOW_W           = 800
M.WINDOW_H           = 600

M.TILE_COLORS        = {
    [0]    = { bg = { 0.80, 0.75, 0.70 }, fg = { 0.47, 0.43, 0.40 } },
    [2]    = { bg = { 0.93, 0.89, 0.85 }, fg = { 0.47, 0.43, 0.40 } },
    [4]    = { bg = { 0.93, 0.87, 0.78 }, fg = { 0.47, 0.43, 0.40 } },
    [8]    = { bg = { 0.95, 0.69, 0.47 }, fg = { 1.00, 1.00, 1.00 } },
    [16]   = { bg = { 0.96, 0.58, 0.39 }, fg = { 1.00, 1.00, 1.00 } },
    [32]   = { bg = { 0.96, 0.49, 0.37 }, fg = { 1.00, 1.00, 1.00 } },
    [64]   = { bg = { 0.96, 0.37, 0.23 }, fg = { 1.00, 1.00, 1.00 } },
    [128]  = { bg = { 0.93, 0.81, 0.45 }, fg = { 1.00, 1.00, 1.00 } },
    [256]  = { bg = { 0.93, 0.80, 0.38 }, fg = { 1.00, 1.00, 1.00 } },
    [512]  = { bg = { 0.93, 0.78, 0.31 }, fg = { 1.00, 1.00, 1.00 } },
    [1024] = { bg = { 0.93, 0.77, 0.25 }, fg = { 1.00, 1.00, 1.00 } },
    [2048] = { bg = { 0.93, 0.76, 0.18 }, fg = { 1.00, 1.00, 1.00 } },
}
M.DEFAULT_TILE_COLOR = { bg = { 0.24, 0.23, 0.20 }, fg = { 1.00, 1.00, 1.00 } }

M.WIN_TILE           = 2048

M.TRANSITION_EASE     = tween.ease(tween.Curve.Bounce, tween.Mode.Out)
M.TRANSITION_DURATION = 1

M.ANIM_DURATION      = 0.1
M.MERGE_EFFECT_DURATION = 0.12
M.ANIMATIONS_ENABLED = true
M.EFFECTS_ENABLED    = true

M.TILESET            = ""
M.TILESET_ANIM_FPS   = 12

M.SOUND = {
    ENABLED    = true,
    TRANSITION = "assets/Audio/open_001.ogg",
    SELECT     = "assets/Audio/tick_001.ogg",
    CHANGE     = "assets/Audio/switch_001.ogg",
    SLIDE      = "assets/Audio/click_001.ogg",
}

M.PARTICLE = {
    COUNT_MIN    = 500,
    COUNT_MAX    = 1000,
    SIZE         = 5,
    LIFETIME_MIN = 1.5,
    LIFETIME_MAX = 4.5,
    SPEED_MIN    = 0.15,
    SPEED_MAX    = 0.45,
    GRAVITY      = 0.6,

    -- PICO-8 base palette, as {r,g,b} triples in the 0-1 range
    COLORS = {
        { 0.00, 0.00, 0.00 }, -- black
        { 0.11, 0.17, 0.33 }, -- dark blue
        { 0.49, 0.15, 0.33 }, -- dark purple
        { 0.00, 0.53, 0.32 }, -- dark green
        { 0.67, 0.32, 0.21 }, -- brown
        { 0.37, 0.34, 0.31 }, -- dark gray
        { 0.76, 0.76, 0.78 }, -- light gray
        { 1.00, 0.95, 0.91 }, -- white
        { 1.00, 0.00, 0.30 }, -- red
        { 1.00, 0.64, 0.00 }, -- orange
        { 1.00, 0.93, 0.15 }, -- yellow
        { 0.00, 0.89, 0.21 }, -- green
        { 0.16, 0.68, 1.00 }, -- blue
        { 0.51, 0.46, 0.61 }, -- lavender
        { 1.00, 0.47, 0.66 }, -- pink
        { 1.00, 0.80, 0.67 }, -- peach
    },
}

return M
