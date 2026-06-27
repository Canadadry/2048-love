love = {
    graphics   = {
        getDimensions = function() return 600, 600 end,
        newFont       = function(size)
            return {
                getWidth  = function(self, s) return #s * 7 end,
                getHeight = function(self) return 18 end,
                getWrap   = function(self, text, width) return 0, { text } end,
            }
        end,
        setColor  = function(...) end,
        rectangle = function(...) end,
        draw      = function(...) end,
        printf    = function(...) end,
        setFont   = function(...) end,
    },
    filesystem = {
        getDirectoryItems = function(_) return { "jurassic-park.lua", "jurassic-park.png" } end,
        read              = function(_) return nil end,
        write             = function(_, _) return true end,
    },
}

local i18n = require("lib.i18n")
i18n.load(table.concat({
    "key,en,fr",
    "lang.name,English,Français",
    "options.win_tile,Win Tile,Tuile gagnante",
    "options.theme,Theme,Thème",
    "options.animations,Animations,Animations",
    "options.effects,Effects,Effets",
    "options.sound,Sound,Son",
    "options.music,Music,Musique",
    "options.language,Language,Langue",
    "options.on,ON,OUI",
    "options.off,OFF,NON",
    "options.theme_none,None (classic),Aucun (classique)",
    "menu.back,Back,Retour",
    "screen.options,Options,Options",
    'options.hint,"Up/Down to focus a row, Left/Right to change its value, or tap a row","Haut/Bas pour naviguer, Gauche/Droite pour changer, ou appuyer sur une ligne"',
}, "\n"))

local options_screen = require("screens.options_screen")
local config         = require("config")
local settings       = require("lib.settings")
local menu           = require("menu")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local function stub_host()
    local main_menu_sentinel = { sentinel = "main_menu" }
    return {
        replace_calls = {},
        replace       = function(self, screen) table.insert(self.replace_calls, screen) end,
        spawn         = function(self, name) if name == "main_menu" then return main_menu_sentinel end end,
        _main_menu    = main_menu_sentinel,
    }
end

local function new_screen()
    local host = stub_host()
    local screen = options_screen.new(host)
    screen:enter()
    return screen, host
end

local function interactive_centers(tree)
    local centers = {}
    for _, cmd in ipairs(tree.Commands) do
        if cmd.painter and (cmd.painter.kind == "Group" or cmd.painter.kind == "Interactive") then
            table.insert(centers, { x = cmd.x + cmd.w / 2, y = cmd.y + cmd.h / 2 })
        end
    end
    return centers
end

-- maps a 0-based item index (Win Tile=0, Theme=1, Animations=2, Effects=3,
-- Sound=4, Music=5, Language=6, Back=8; the hint at index 7 is non-interactive) to its tap coordinates.
local INTERACTIVE_INDEX = { [0]=1, [1]=2, [2]=3, [3]=4, [4]=5, [5]=6, [6]=7, [8]=8 }

local function tap_item(screen, item_index)
    local centers = interactive_centers(menu.menu_tree(screen:spec(), screen:cursor(), nil))
    local c = centers[INTERACTIVE_INDEX[item_index]]
    screen:tap(c.x, c.y)
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("escape calls host:replace() with the main menu screen", function()
    local screen, host = new_screen()
    screen:keypressed("escape")
    eq(#host.replace_calls, 1, "host:replace() called once")
    eq(host.replace_calls[1], host._main_menu, "replaced with main menu screen")
end)

-- ── Cycle 2: enter() defaults cursor to the first item (Win Tile) ────────────

test("entering options defaults the cursor to the first item (Win Tile)", function()
    local screen = new_screen()
    eq(screen:cursor(), 0, "cursor starts on Win Tile")
end)

-- ── Cycle 3: up/down move the cursor, wrapping, skipping the hint ───────────

test("down/up move the cursor between items, wrapping at both ends and skipping the hint", function()
    local screen = new_screen()
    screen:keypressed("down")
    eq(screen:cursor(), 1, "down moves to Theme")
    screen:keypressed("down")
    eq(screen:cursor(), 2, "down moves to Animations")
    screen:keypressed("down")
    eq(screen:cursor(), 3, "down moves to Effects")
    screen:keypressed("down")
    eq(screen:cursor(), 4, "down moves to Sound")
    screen:keypressed("down")
    eq(screen:cursor(), 5, "down moves to Music")
    screen:keypressed("down")
    eq(screen:cursor(), 6, "down moves to Language")
    screen:keypressed("down")
    eq(screen:cursor(), 8, "down skips the hint and lands on Back")
    screen:keypressed("down")
    eq(screen:cursor(), 0, "down wraps from Back back to Win Tile")
    screen:keypressed("up")
    eq(screen:cursor(), 8, "up wraps from Win Tile to Back")
end)

-- ── Cycle 4: left/right on Win Tile toggles + persists config.WIN_TILE ───────

test("left/right on the Win Tile item toggle config.WIN_TILE immediately, without affecting cursor or Theme", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("right")
    eq(config.WIN_TILE, 16, "win tile toggled to 16 (dev mode)")
    eq(screen:cursor(), 0, "cursor stays on Win Tile")
    eq(config.TILESET, "", "Theme untouched by Win Tile toggling")
    screen:keypressed("left")
    eq(config.WIN_TILE, 2048, "win tile toggled back to 2048 (prod mode)")
end)

test("toggling Win Tile persists the new value via settings.set", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("right")
    eq(settings.get("win_tile", nil), 16, "win_tile persisted on toggle")
    screen:keypressed("left")
end)

-- ── Cycle 5: left/right on Theme cycles + persists config.TILESET ────────────

test("left/right on the Theme item cycle config.TILESET through available themes, wrapping, applied immediately", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("down")
    eq(screen:cursor(), 1, "cursor on Theme")
    screen:keypressed("right")
    eq(config.TILESET, "jurassic-park", "theme advanced without needing return")
    screen:keypressed("right")
    eq(config.TILESET, "", "theme wraps back to None sentinel")
    screen:keypressed("left")
    eq(config.TILESET, "jurassic-park", "left wraps backward to the last theme")
    config.TILESET = ""
end)

test("cycling Theme persists the new value via settings.set", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("theme", nil), "jurassic-park", "theme persisted on cycle")
    config.TILESET = ""
end)

-- ── Cycle 6: left/right on Animations/Effects toggles + persists ────────────

test("left/right on the Animations item toggles config.ANIMATIONS_ENABLED, applied immediately", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:cursor(), 2, "cursor on Animations")
    screen:keypressed("right")
    eq(config.ANIMATIONS_ENABLED, false, "animations toggled off")
    screen:keypressed("left")
    eq(config.ANIMATIONS_ENABLED, true, "animations toggled back on")
end)

test("toggling Animations persists the new value via settings.set", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("animations_enabled", nil), false, "animations_enabled persisted on toggle")
    screen:keypressed("left")
end)

test("left/right on the Effects item toggles config.EFFECTS_ENABLED, applied immediately", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:cursor(), 3, "cursor on Effects")
    screen:keypressed("right")
    eq(config.EFFECTS_ENABLED, false, "effects toggled off")
    screen:keypressed("left")
    eq(config.EFFECTS_ENABLED, true, "effects toggled back on")
end)

test("toggling Effects persists the new value via settings.set", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("effects_enabled", nil), false, "effects_enabled persisted on toggle")
    screen:keypressed("left")
end)

-- ── Cycle 7: Sound toggle ─────────────────────────────────────────────────────

test("left/right on the Sound item toggles config.SOUND.ENABLED, applied immediately", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:cursor(), 4, "cursor on Sound")
    screen:keypressed("right")
    eq(config.SOUND.ENABLED, false, "sound toggled off")
    screen:keypressed("left")
    eq(config.SOUND.ENABLED, true, "sound toggled back on")
end)

test("toggling Sound persists the new value via settings.set", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("sound_enabled", nil), false, "sound_enabled persisted on toggle")
    screen:keypressed("left")
end)

-- ── Cycle 8: Music toggle ─────────────────────────────────────────────────────

test("left/right on the Music item toggles config.MUSIC.ENABLED, applied immediately", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    eq(screen:cursor(), 5, "cursor on Music")
    screen:keypressed("right")
    eq(config.MUSIC.ENABLED, false, "music toggled off")
    screen:keypressed("left")
    eq(config.MUSIC.ENABLED, true, "music toggled back on")
end)

test("toggling Music persists the new value via settings.set", function()
    local screen = new_screen()
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("music_enabled", nil), false, "music_enabled persisted on toggle")
    screen:keypressed("left")
end)

-- ── Cycle 9: left/right on the Back item is inert ────────────────────────────

test("left/right on the Back item change nothing observable", function()
    config.TILESET = ""
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 8, "cursor on Back")
    local settings_before = settings.get("effects_enabled", nil)
    screen:keypressed("right")
    eq(screen:cursor(), 8, "cursor unchanged by right")
    eq(config.EFFECTS_ENABLED, true, "no row's config mutated by right on Back")
    eq(settings.get("effects_enabled", nil), settings_before, "no settings write from right on Back")
    screen:keypressed("left")
    eq(screen:cursor(), 8, "cursor unchanged by left")
    eq(config.EFFECTS_ENABLED, true, "no row's config mutated by left on Back")
end)

test("left/right on the Back item never calls settings.set", function()
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 8, "cursor on Back")
    local calls = 0
    local real_set = settings.set
    settings.set = function(...) calls = calls + 1; return real_set(...) end
    screen:keypressed("right")
    screen:keypressed("left")
    settings.set = real_set
    eq(calls, 0, "settings.set must not be called for the Back item")
end)

-- ── Cycle 9: tap focus-then-activate semantics ───────────────────────────────

test("tapping an unfocused item focuses it without changing its value", function()
    local screen = new_screen()
    tap_item(screen, 1)
    eq(screen:cursor(), 1, "tap focuses the Theme item")
    eq(config.WIN_TILE, 2048, "Win Tile value unchanged by a focus-only tap")
end)

test("tapping the already-focused item cycles its value forward, like right()", function()
    local screen = new_screen()
    tap_item(screen, 1)                -- move cursor off Win Tile first
    tap_item(screen, 0)                -- focus-only tap: lands on Win Tile, no cycle
    eq(screen:cursor(), 0, "now focused on Win Tile")
    eq(config.WIN_TILE, 2048, "focus-only tap left the value untouched")
    tap_item(screen, 0)                -- second tap: item already focused, cycles
    eq(config.WIN_TILE, 16, "second tap on the focused item cycles the value forward")
    tap_item(screen, 0)                -- revert
end)

test("tapping the already-focused Win Tile item persists the new value via settings.set", function()
    local screen = new_screen()
    tap_item(screen, 1)
    tap_item(screen, 0)
    tap_item(screen, 0)
    eq(settings.get("win_tile", nil), 16, "win_tile persisted on tap-cycle")
    tap_item(screen, 0)                -- revert
end)

-- ── Cycle 10: tap on Back / return on Back replaces with main menu ───────────

test("tapping the Back item twice (focus, then activate) calls host:replace() once", function()
    local screen, host = new_screen()
    tap_item(screen, 8)
    eq(screen:cursor(), 8, "first tap focuses Back")
    eq(#host.replace_calls, 0, "still on options after focus-only tap")
    tap_item(screen, 8)
    eq(#host.replace_calls, 1, "second tap on focused Back calls replace")
    eq(host.replace_calls[1], host._main_menu, "replaced with main menu screen")
end)

test("return has no observable effect on the Options screen, except when Back is focused", function()
    config.TILESET = ""
    local screen, host = new_screen()
    screen:keypressed("return")
    eq(#host.replace_calls, 0, "return does not navigate when Back isn't focused")
    eq(screen:cursor(), 0, "cursor unchanged by return")
    eq(config.WIN_TILE, 2048, "win tile unchanged by return")
    eq(config.TILESET, "", "theme unchanged by return")
end)

test("return while Back is focused calls host:replace() with the main menu screen", function()
    local screen, host = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 8, "cursor on Back")
    screen:keypressed("return")
    eq(#host.replace_calls, 1, "return on Back calls replace")
    eq(host.replace_calls[1], host._main_menu, "replaced with main menu screen")
end)

-- ── Cycle 11: draw() runs without erroring ────────────────────────────────────

test("draw() runs without erroring", function()
    local screen = new_screen()
    screen:draw()
    eq(true, true, "no crash")
end)

-- ── Cycle 12: immediate label refresh ────────────────────────────────────────

test("boolean option values reflect the active language immediately after cycling Language", function()
    i18n.set_lang("en")
    config.ANIMATIONS_ENABLED = true
    local screen = new_screen()
    local spec_en = screen:spec()
    eq(spec_en.items[3].value, "ON", "Animations value is ON in English")
    -- Switch to French
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    screen:keypressed("right")
    eq(i18n.lang(), "fr", "language switched to fr")
    local spec_fr = screen:spec()
    eq(spec_fr.items[3].value, "OUI", "Animations value updates to OUI immediately in French")
    i18n.set_lang("en")
end)

test("item labels reflect the active language immediately after cycling Language", function()
    i18n.set_lang("en")
    local screen = new_screen()
    local spec_en = screen:spec()
    eq(spec_en.items[1].label, "Win Tile", "Win Tile label is English before change")
    eq(spec_en.title, "Options", "title is English before change")
    -- Navigate to Language and switch to French
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    screen:keypressed("right")
    eq(i18n.lang(), "fr", "language switched to fr")
    local spec_fr = screen:spec()
    eq(spec_fr.items[1].label, "Tuile gagnante", "Win Tile label updates to French immediately")
    eq(spec_fr.title, "Options", "title updates to French immediately")
    i18n.set_lang("en")
end)

-- ── Cycle 12: Language row ────────────────────────────────────────────────────

test("Language row is at cursor index 6 and can be focused with down", function()
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 6, "sixth down lands on Language")
end)

test("right on Language advances i18n active language to the next one", function()
    i18n.set_lang("en")
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    eq(screen:cursor(), 6, "cursor on Language")
    screen:keypressed("right")
    eq(i18n.lang(), "fr", "right advanced language to fr")
    i18n.set_lang("en")
end)

test("cycling Language persists the new language code via settings.set", function()
    i18n.set_lang("en")
    local screen = new_screen()
    screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down"); screen:keypressed("down")
    screen:keypressed("right")
    eq(settings.get("language", nil), "fr", "language persisted on cycle")
    i18n.set_lang("en")
end)

T.report()
