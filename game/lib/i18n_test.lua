local i18n = require("lib.i18n")

local T    = require("lib.t")
local test = T.test
local eq   = T.eq

local MINI_CSV = table.concat({
    "key,en,fr",
    "lang.name,English,Français",
    "menu.new_game,New Game,Nouvelle partie",
    "menu.quit,Quit,Quitter",
    "menu.only_en,Only English,",
}, "\n")

-- ── Cycle 1: tracer bullet ────────────────────────────────────────────────────

test("t() returns the correct value for the active language", function()
    i18n.load(MINI_CSV)
    i18n.set_lang("fr")
    eq(i18n.t("menu.new_game"), "Nouvelle partie", "French translation returned")
end)

-- ── Cycle 2: fallback to English ──────────────────────────────────────────────

test("t() falls back to English when the current language has no value for a key", function()
    i18n.load(MINI_CSV)
    i18n.set_lang("fr")
    eq(i18n.t("menu.only_en"), "Only English", "falls back to English when fr value is empty")
end)

-- ── Cycle 3: fallback to raw key ──────────────────────────────────────────────

test("t() falls back to the raw key when absent from both current language and English", function()
    i18n.load(MINI_CSV)
    i18n.set_lang("en")
    eq(i18n.t("no.such.key"), "no.such.key", "missing key returns raw key string")
end)

-- ── Cycle 4: set_lang with unknown code ──────────────────────────────────────

test("set_lang() with an unknown code silently falls back to 'en'", function()
    i18n.load(MINI_CSV)
    i18n.set_lang("zz")
    eq(i18n.lang(), "en", "unknown lang code defaults to en")
    eq(i18n.t("menu.new_game"), "New Game", "translations use en after fallback")
end)

-- ── Cycle 5: languages() ──────────────────────────────────────────────────────

test("languages() returns the correct ordered list of {code, name} pairs", function()
    i18n.load(MINI_CSV)
    local langs = i18n.languages()
    eq(#langs, 2,          "two languages")
    eq(langs[1].code, "en",       "first code is en")
    eq(langs[1].name, "English",  "en name is English")
    eq(langs[2].code, "fr",       "second code is fr")
    eq(langs[2].name, "Français", "fr name is Français")
end)

-- ── Cycle 7: quoted CSV fields with embedded commas ──────────────────────────

test("t() returns values that contain commas when the CSV field is double-quoted", function()
    local csv_with_commas = table.concat({
        'key,en,fr',
        'lang.name,English,Français',
        'ui.hint,"Up, Down to focus","Haut, Bas pour naviguer"',
    }, "\n")
    i18n.load(csv_with_commas)
    i18n.set_lang("en")
    eq(i18n.t("ui.hint"), "Up, Down to focus",      "English quoted value with comma")
    i18n.set_lang("fr")
    eq(i18n.t("ui.hint"), "Haut, Bas pour naviguer", "French quoted value with comma")
end)

-- ── Cycle 6: load() resets state ──────────────────────────────────────────────

test("load() called a second time resets state from the first load", function()
    i18n.load(MINI_CSV)
    i18n.set_lang("fr")
    eq(i18n.t("menu.new_game"), "Nouvelle partie", "French before second load")

    local other_csv = "key,en\nlang.name,English\nother.key,Other Value"
    i18n.load(other_csv)
    i18n.set_lang("en")
    eq(i18n.t("menu.new_game"), "menu.new_game", "old key gone after second load")
    eq(i18n.t("other.key"), "Other Value",       "new key works after second load")
    local langs = i18n.languages()
    eq(#langs, 1, "only one language after second load")
    eq(langs[1].code, "en", "sole language is en")
end)

T.report()
