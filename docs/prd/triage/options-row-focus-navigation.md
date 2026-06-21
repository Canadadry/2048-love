---
title: "Options Row Focus Navigation"
description: "Win Tile and Theme on the Options screen use inconsistent, simultaneously-live controls (Left/Right always edits Win Tile, Up/Down always edits Theme); this replaces them with a single row-focus model."
status: needs-triage
---

# Options Row Focus Navigation

## Problem Statement

The Options screen currently mixes two incompatible input schemes on one screen. Win Tile has no concept of focus: Left/Right toggles it immediately no matter where the player's attention is. Theme has a cursor moved by Up/Down, applied by Enter. Both controls are always "live" at once, but each only reacts to a different pair of keys, with no visual indication that this split exists. Players find the screen confusing to interact with — pressing a direction does something, but it's not obvious why that key affected one setting and not the other, and the two settings apply at different times (Win Tile immediately, Theme only on Enter).

## Solution

The Options screen becomes a two-row list — Win Tile, then Theme — navigated with Up/Down, which moves a single focus indicator (highlighted in the accent color) between rows and wraps at both ends. Left/Right always acts on whichever row currently has focus, cycling that row's value and wrapping at both ends of its value list. Every change applies immediately, with no separate confirm step. Theme collapses from its current multi-line list display to a single line (`Theme: < jurassic-park >`), matching Win Tile's existing format (`Win Tile: < 2048 >`). Enter has no effect on this screen; Escape still returns to the main menu. Main Menu, Pause, and Win overlay are unchanged — they have no editable values, so the inconsistency doesn't apply there.

## User Stories

1. As a player, I want Up/Down to move between Win Tile and Theme, so that I always know which setting I'm about to change.
2. As a player, I want Left/Right to only ever change the setting I'm currently focused on, so that I never accidentally change the wrong value.
3. As a player, I want a clear visual highlight on the row I'm focused on, so that I don't have to guess which control my next keypress will affect.
4. As a player, I want every change to apply the instant I press Left/Right, so that I don't need to remember to press Enter to confirm.
5. As a player, I want Up/Down to wrap around at the top/bottom row, so that I can reach either row quickly regardless of where I currently am.
6. As a player, I want Left/Right on the Theme row to wrap around at the first/last theme, so that cycling through themes is quick in either direction.
7. As a player, I want the Theme row to show just the current theme name (not the full list), so that the screen looks and behaves the same as the Win Tile row.
8. As a player, I want pressing Enter on the Options screen to do nothing harmful, so that muscle memory from other menus doesn't accidentally trigger an unrelated action.
9. As a player, I want Escape to still return me to the main menu from any row, so that leaving Options works the same as before regardless of focus.
10. As a developer, I want the row-focus and value-cycling logic in a module with no Love2D dependency, so that it can be unit tested without stubbing the game loop.

## Implementation Decisions

- **`game/optionsmodel.lua` (new, pure deep module)** — no Love2D or `config` dependency. Constructed from a declarative row list, where each row has a label and an ordered list of values plus a starting value-index. Exposes:
  - `up()` / `down()` — move focus between rows, wrapping at both ends.
  - `left()` / `right()` — cycle the value-index of the currently focused row, wrapping at both ends of that row's value list.
  - `focused_row()` — index of the row currently in focus.
  - `row_value(i)` — current value of row `i` (for rendering and read-back).
  - This module owns no game state; it is pure data-in/data-out, fully testable with plain Lua and no stubs.
- **`game/options.lua` (`OptionsState`, modified)** — on `enter()`, builds an `optionsmodel` instance with two rows: Win Tile (values `{32, 2048}`, starting index from `config.WIN_TILE`) and Theme (values from `tileset.list_available()`, starting index matching `config.TILESET`). `keypressed` delegates `up`/`down`/`left`/`right` to the model. After any `left`/`right`, the focused row's new value is written straight through to the corresponding global (`config.WIN_TILE` or `config.TILESET`) — there is no pending/uncommitted state. `return` is a no-op. `escape` is unchanged (`ctx.switch("menu")`).
- **`game/main.lua` (modified)** — the existing hot-swap call site (currently `if state:in_options() and key == "return" then renderer.set_tileset(config.TILESET) end`) moves to fire on `left`/`right` while `state:in_options()` instead of on `return`. Calling `set_tileset` on a Win Tile change (where the tileset didn't actually change) is a harmless no-op rebuild.
- **`game/menu.lua` `draw_options` (modified)** — renders two single-line rows in place of the current Win Tile line + multi-line Theme list:
  - `Win Tile: < 2048 >`
  - `Theme: < jurassic-park >`
  - Whichever row currently has focus (queried from the state, mirroring how `tileset_cursor()` is exposed today) is drawn in the existing accent/highlight color; the other row uses normal text color.
  - Hint text is updated to a single line describing Up/Down for row focus and Left/Right for value, replacing the two separate hints ("Left/Right to change" and "Up/Down to select, Enter to apply").
- No changes to Main Menu, Pause, or Win overlay screens — they have no editable values and already follow an up/down-select + Enter-confirm pattern that this PRD doesn't touch.

## Testing Decisions

- Tests should assert externally observable behavior (focus position, row values, wrap behavior) rather than internal table shape.
- **`tests/test_optionsmodel.lua` (new)** — pure unit tests against `optionsmodel.lua` directly, no Love2D stubs required:
  - `up()`/`down()` move focus and wrap at both ends of the row list.
  - `left()`/`right()` only change the focused row's value, never another row's.
  - `left()`/`right()` wrap at both ends of the focused row's value list.
  - Changing focus does not change any row's current value.
- **`tests/test_options.lua` (rewritten)** — integration tests through `gamestate.new()`, replacing the current cursor/Enter-based assertions (`tileset_cursor()`, Enter-to-apply) with assertions against the new row-focus model:
  - Entering Options defaults focus to the first row (Win Tile).
  - `down`/`up` move focus between Win Tile and Theme, wrapping at both ends.
  - `left`/`right` on the Win Tile row toggle `config.WIN_TILE` between 32 and 2048 immediately, without affecting focus or the Theme row.
  - `left`/`right` on the Theme row cycle `config.TILESET` through available themes immediately (including the "None" sentinel), wrapping at both ends, without requiring `return`.
  - `return` has no observable effect.
  - `escape` returns to the main menu regardless of which row has focus.
  - Prior art: existing `in_options()` test helper and `love.filesystem.getDirectoryItems` stub at the top of `tests/test_options.lua` carry over unchanged.
- `game/menu.lua` `draw_options` remains untested, consistent with the existing convention in this repo that `draw_*` rendering functions are not unit tested.

## Out of Scope

- Any changes to Main Menu, Pause, or Win overlay input handling.
- Adding new Options rows beyond Win Tile and Theme.
- Settings persistence (covered separately by `docs/prd/triage/settings-persistence.md`).
- Visual/animation polish on the focus highlight transition (e.g. easing between rows).
- Gamepad or touch input for the Options screen.

## Further Notes

This PRD resolves a UX complaint raised by the developer: the old screen let two settings be "edited" at once via different, non-overlapping key directions (Left/Right always live for Win Tile, Up/Down always live for Theme), with no way to tell which one a keypress would affect. The new model guarantees exactly one row is editable at any time, and that row is always the one visibly in focus.
