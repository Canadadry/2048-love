---
title: "Animation & Effect Toggles"
description: "Slide animation and merge pop/scale effect are always on. Players on low-end hardware or with a preference for instant feedback cannot disable them."
status: done
---

# Animation & Effect Toggles

## Problem Statement

Slide animation and merge pop/scale effect are always on. Players on low-end hardware or with a preference for instant feedback cannot disable them.

## Solution

Add two toggles to the Options screen: one for slide animation, one for the merge pop/scale effect. Each is flipped with Left/Right, same as the existing Win Tile and Theme rows.

## User Stories

1. As a player, I want to toggle slide animation on or off from the Options screen, so that I can prefer instant moves if desired.
2. As a player, I want to toggle the merge pop/scale effect on or off from the Options screen, so that I can reduce visual noise.
3. As a player, I want the toggles to take effect immediately, so that I can see the result without restarting.

## Implementation Decisions

- **`config.lua`** gains `ANIMATIONS_ENABLED = true` and `EFFECTS_ENABLED = true`, following the same live-mutable-value pattern as `WIN_TILE` and `TILESET` (not a separate settings table — `settings.lua` is a generic key/value store already used to persist both).
- **`gamestate.lua`**: `Base:animations_enabled()` / `Base:effects_enabled()` accessors mirror `win_tile()`/`theme()`. `apply_move()` skips creating `AnimTile`s entirely when `config.ANIMATIONS_ENABLED` is false — the grid has already mutated synchronously, so cells render in their new positions with no interpolation needed. Separately, it passes `m.merged and config.EFFECTS_ENABLED` (instead of bare `m.merged`) to `tile.new()`, so a merging tile's pop is suppressed without any change to `tile.lua` itself.
- **`options.lua`** gains two new rows, **Animations** and **Effects**, using the existing `optionsmodel` with `{ true, false }` value lists. Left/Right flips `config.ANIMATIONS_ENABLED` / `config.EFFECTS_ENABLED` and persists via `settings.set`, identical to the Win Tile/Theme rows.
- **`menu.lua`** `draw_options()` gains two more rows ("Animations: ON/OFF", "Effects: ON/OFF") and two new parameters; **`main.lua`** wires the new accessors through to both `draw_options()` and `love.load()`'s settings-seeding block.

## Testing Decisions

- `tests/test_gamestate.lua`: a move with `ANIMATIONS_ENABLED = false` produces zero `anim_tiles` (`is_animating()` stays false); a merge with `EFFECTS_ENABLED = false` (but animations on) still slides but every resulting tile's `scale` stays `1.0` through the pop window.
- `tests/test_options.lua`: both new rows default to `true`; Left/Right toggles and persists each independently; the existing 2-row up/down wrap test is extended to all 4 rows.
- `tests/test_main.lua`: launch seeds `config.ANIMATIONS_ENABLED`/`config.EFFECTS_ENABLED` from saved settings, same pattern as Win Tile/Theme.
- No changes needed to `tile.lua` or its tests — the toggle is enforced entirely at the call site in `gamestate.lua`.

## Out of Scope

- Fine-grained animation speed control.
- A `--no-animations` launch flag (Win Tile is the only setting with a CLI override).
