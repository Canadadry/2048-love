---
title: "Tileset Picker"
description: "Changing the active tileset requires manually editing config.lua. Players cannot switch tilesets at runtime."
status: needs-triage
---

# Tileset Picker

## Problem Statement

Changing the active tileset requires manually editing `config.lua`. Players cannot switch tilesets at runtime.

## Solution

The Options screen lists all PNG files found in the `tilesets/` folder. The player navigates the list with arrow keys. The selected entry shows a preview of the first frame of the first four tile values (2, 4, 8, 16). Selecting a tileset applies it immediately for the current session (persistence comes in PRD 012).

## User Stories

1. As a player, I want to see all available tilesets listed in the Options screen, so that I know what I can choose from.
2. As a player, I want to navigate the tileset list with Up/Down arrow keys, so that selection is consistent with the rest of the UI.
3. As a player, I want to see a preview of the first four tile values for each listed tileset, so that I can identify the style before applying it.
4. As a player, I want to confirm my tileset selection with Enter, so that it becomes active immediately.
5. As a player, I want a "None (classic)" entry at the top of the list, so that I can revert to the default color rendering.

## Implementation Decisions

- **`options.lua`** — on `enter()`, scans `tilesets/` with `love.filesystem.getDirectoryItems()`, filters for `.png` files, prepends a "None" sentinel entry. Holds `cursor` (index into the list) and `preview_tileset` (a tileset instance loaded from the highlighted entry, or `nil` for "None").
- **`tileset.lua`** — `load(path)` is already implemented (PRD 007). A second instance is created for preview purposes; it does not replace the active game tileset until the player confirms with Enter.
- Preview rendering: draw four quads (values 2, 4, 8, 16, frame 0) side by side next to the highlighted list entry.
- On Enter: the preview tileset becomes the active tileset (passed to renderer). The previous active tileset is discarded.
- **`renderer.lua`** — active tileset is now a runtime value passed in, not a config-time constant. `renderer.set_tileset(tileset_or_nil)` replaces the internal reference.

## Testing Decisions

- Test that the directory scan produces a list sorted alphabetically with "None" prepended.
- Test that selecting "None" sets the active tileset to `nil`.

## Out of Scope

- Persistence of the chosen tileset (PRD 012).
- Previewing animated frames (first frame only is shown).
- Subfolder organization of tilesets.

## Further Notes

`love.filesystem.getDirectoryItems()` only finds files inside the Love2D save directory or the game source directory — tilesets must be placed in a `tilesets/` folder at the game root.
