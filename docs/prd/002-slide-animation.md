---
title: "Slide Animation"
description: "Tiles snap instantly to their new positions, making it hard to follow which tile moved where, especially when multiple tiles slide simultaneously."
status: done
---

# Slide Animation

## Problem Statement

Tiles snap instantly to their new positions, making it hard to follow which tile moved where, especially when multiple tiles slide simultaneously.

## Solution

Tiles animate from their source cell to their destination cell over a configurable duration. Input is blocked during animation to prevent move queuing.

## User Stories

1. As a player, I want tiles to visually slide to their new positions when I press an arrow key, so that I can follow the movement.
2. As a player, I want all tiles to animate simultaneously, so that the move feels responsive.
3. As a player, I want the animation duration to be a tunable value, so that the feel can be adjusted.
4. As a player, I want my key press to be ignored while tiles are still animating, so that I do not accidentally trigger double-moves.

## Implementation Decisions

- **`tile.lua`** — new module. A tile is a table with: `value`, `draw_x`, `draw_y`, `target_x`, `target_y`, `timer`. `draw_x`/`draw_y` are pixel positions updated each `update(dt)`. When `timer >= ANIM_DURATION`, the tile snaps to `target_x`/`target_y` exactly.
- **`grid.lua`** — `move()` now returns a list of tile movement descriptors `{from_col, from_row, to_col, to_row, value}` instead of just the resulting board. The calling state constructs `tile.lua` instances from these descriptors.
- **`gamestate.lua`** — playing state holds a list of active tile animations. Input is gated: `if #animations == 0 then accept_input() end`.
- **`renderer.lua`** — draws tiles at their current `draw_x`/`draw_y` rather than from grid cell coordinates.
- **`config.lua`** — gains `ANIM_DURATION` (seconds, e.g. `0.1`).

## Testing Decisions

- No animation-specific unit tests — animation is pure visual interpolation with no branching logic worth testing in isolation.
- Existing `grid.lua` tests remain valid; the movement descriptor output is an additive change, not a replacement.

## Out of Scope

- Merge pop/scale effect (PRD 004).
- Easing functions (linear interpolation is sufficient for now).

## Further Notes

Pixel positions are derived from cell coordinates and current window size, so they must be recomputed when `love.resize` fires mid-animation. The simplest fix: on resize, snap all in-flight animations to their target immediately.
