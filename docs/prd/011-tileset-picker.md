---
title: "Tileset Picker"
description: "Changing the active tileset required manually editing config.lua. The Options screen now lists built themes and switches between them at runtime."
status: done
---

# Tileset Picker

## Problem Statement

Changing the active tileset required manually editing `config.lua`. Players could not switch tilesets at runtime.

## Solution

The Options screen lists a "None (classic)" entry plus every theme tilesheet found in `game/assets/` (the gitignored build output of `theme-builder`, not the `tilesets/` folder originally proposed — see Further Notes). The player navigates the list with Up/Down and confirms with Enter, applying the selected theme immediately for the current session.

## User Stories

1. As a player, I want to see all available themes listed in the Options screen, so that I know what I can choose from.
2. As a player, I want to navigate the theme list with Up/Down arrow keys, so that selection is consistent with the rest of the UI.
3. As a player, I want to confirm my theme selection with Enter, so that it becomes active immediately.
4. As a player, I want a "None (classic)" entry at the top of the list, so that I can revert to the default color rendering.

## Implementation Decisions

- **`tileset.lua`** — `list_names(filenames)` is a pure function: filters for `.png` suffix, strips the extension, sorts alphabetically, and prepends `""` as the "None" sentinel. `list_available()` wraps it with `love.filesystem.getDirectoryItems("assets")`. `load(name)` now takes an explicit name argument instead of reading `config.TILESET` internally, so a preview/candidate tileset can be loaded without mutating global state.
- **`options.lua`** — on `enter()`, builds `self._names` via `tileset.list_available()` and defaults `self._cursor` to the index of the currently active `config.TILESET` (or 1, "None", if unset). `up`/`down` move the cursor clamped to the list bounds; `return` sets `config.TILESET` to the highlighted name. `left`/`right` continue to toggle the unrelated Win Tile setting.
- **`gamestate.lua`**'s `Base` gains `tileset_names()` (default `{}`) and `tileset_cursor()` (default `0`), overridden by `OptionsState`.
- **`renderer.lua`** — the body of the old `M.load()` was extracted into `M.set_tileset(name)`, which rebuilds the active quads/image for a given name (or clears them for `""`/missing). `M.load()` is now just `M.set_tileset(config.TILESET)` at startup.
- **`menu.lua`**'s `draw_options` renders the theme list as plain text labels (no thumbnail preview), highlighting the cursor row.
- **`main.lua`** calls `renderer.set_tileset(config.TILESET)` whenever Enter is pressed while `state:in_options()`, hot-swapping the board's tileset without restarting.

## Testing Decisions

- `tests/test_tileset.lua` — `list_names` sorts alphabetically with "None" prepended, filtering out non-`.png` entries.
- `tests/test_options.lua` — entering Options lists "None" plus available themes with the cursor on the active theme; Up/Down move and clamp the cursor; Enter on a theme entry sets it active; Enter on "None" clears the active tileset back to `""`.
- `tests/test_all.lua` and `tests/test_menu.lua` gained a baseline `love.filesystem.getDirectoryItems` stub (returning `{}`) so suites that enter the Options state don't crash outside the Love2D runtime.

## Out of Scope

- Persistence of the chosen tileset across launches (PRD 012, `settings-persistence`).
- A visual thumbnail preview of the highlighted theme — the list is text-only.
- Subfolder organization of themes.

## Further Notes

The original triage draft of this PRD described scanning a `tilesets/` folder at the game root. The actual build-output convention (established by `theme-builder`, see `tools/theme-builder/docs/prd/theme-builder.md`) is `game/assets/<name>.png` plus its `.lua` sidecar, which is what `list_available()` scans instead.
