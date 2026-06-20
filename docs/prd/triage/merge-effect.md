Status: needs-triage

# PRD 004 — Merge Pop/Scale Effect

## Problem Statement

Merges are visually silent — the new tile just appears at the destination. Players miss the satisfaction of a visible merge event.

## Solution

When two tiles merge, the resulting tile briefly scales up beyond its normal size then snaps back to 1×, giving a pop effect.

## User Stories

1. As a player, I want merged tiles to briefly grow and shrink after a merge, so that I can clearly see which tiles combined.
2. As a player, I want the pop effect duration to be a tunable value, so that it can be adjusted independently of slide duration.

## Implementation Decisions

- **`tile.lua`** gains two fields: `scale` (default `1.0`) and `merge_timer` (default `0`). When a tile is flagged as a merge result, `merge_timer` is set to `MERGE_EFFECT_DURATION`. Each `update(dt)`, `merge_timer` counts down; `scale` is derived from `merge_timer` via a simple curve (e.g. peaks at `1.2` at the midpoint, returns to `1.0` at `0`).
- **`renderer.lua`** applies a `love.graphics.scale(tile.scale)` transform centered on the tile when drawing.
- **`grid.lua`** `move()` movement descriptors gain a `merged` boolean flag on destination tiles.
- **`config.lua`** gains `MERGE_EFFECT_DURATION` (seconds, e.g. `0.12`).

## Testing Decisions

- No unit tests — the effect is a visual-only interpolation. The `merged` flag on movement descriptors is already covered by `grid.lua` tests.

## Out of Scope

- Particle effects or color flash on merge.
- Chained merge animations.

## Further Notes

The pop effect starts after the slide animation completes to avoid visual overlap — `merge_timer` is initialized only when `tile.timer` reaches zero.
