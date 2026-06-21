---
title: "Merge Pop/Scale Effect"
description: "Merges are visually silent — the new tile just appears at the destination. Players miss the satisfaction of a visible merge event."
status: done
---

# Merge Pop/Scale Effect

## Problem Statement

Merges are visually silent — the new tile just appears at the destination. Players miss the satisfaction of a visible merge event.

## Solution

When two tiles merge, the resulting tile briefly scales up beyond its normal size then snaps back to 1×, giving a pop effect.

## User Stories

1. As a player, I want merged tiles to briefly grow and shrink after a merge, so that I can clearly see which tiles combined.
2. As a player, I want the pop effect duration to be a tunable value, so that it can be adjusted independently of slide duration.

## Implementation Decisions

- **`tile.lua`**: `AnimTile.new()` gains an optional `merged` boolean (7th arg), plus a public `scale` field (default `1.0`) and a private `_merge_timer` (default `0`). `update(dt)` advances the existing slide `_timer` first; once it reaches `_duration`, any leftover `dt` in that same call carries over to count `_merge_timer` down from `config.MERGE_EFFECT_DURATION` — this matters because callers (e.g. `gamestate.lua`'s pause/restart flows) pass oversized `dt` to flush animations instantly in one call, and the slide-then-pop phases both need to resolve within it. `scale` is derived from elapsed pop time via `1.0 + 0.2 * sin(frac * pi)` (peaks at `1.2` at the midpoint, `1.0` at both ends). `is_done()` only reports true once both phases finish for a merged tile; `finish()` resets `_merge_timer` and `scale` immediately.
- **`renderer/tile_draw.lua`**: `M.draw()` gains an optional `pop_scale` arg (default `1`); when not `1`, wraps the draw call in a push/translate/scale/translate-back/pop centered on the tile.
- **`renderer/init.lua`** passes `t.scale` through to `tile_draw.draw()` for animated tiles.
- **`grid.lua`** already had the `merged` boolean flag on movement descriptors from the slide-animation PRD — no change needed.
- **`gamestate.lua`**'s `apply_move()` passes `m.merged` through to `tile.new()`.
- **`config.lua`** gains `MERGE_EFFECT_DURATION = 0.12`.

## Testing Decisions

- `tests/test_tile.lua` covers the pure state machine: a merged tile stays alive through the pop phase after the slide timer reaches duration, becomes done once the pop fully elapses, its `scale` peaks above `1.0` at the pop's midpoint and settles back to `1.0`, `finish()` mid-pop immediately resets it, and a single oversized `dt` flushes both phases in one call (regression coverage for the carry-over behavior, caught via `tests/test_pause.lua`'s existing single-big-update pattern).
- No tests for the `tile_draw.lua` scale transform itself — visual-only, consistent with how that module's other draw paths aren't pixel-tested.

## Out of Scope

- Particle effects or color flash on merge.
- Chained merge animations.
