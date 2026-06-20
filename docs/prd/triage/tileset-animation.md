---
title: "Tileset Animation"
description: "After PRD 007, tileset tiles are static — only the first frame is ever shown. Tilesets with multiple frames per row appear frozen."
status: needs-triage
---

# Tileset Animation (Frame Cycling)

## Problem Statement

After PRD 007, tileset tiles are static — only the first frame is ever shown. Tilesets with multiple frames per row appear frozen.

## Solution

Advance the active frame index on every `love.update` tick. All tiles in the same row share the same frame index (global frame counter), so the sheet animates uniformly.

## User Stories

1. As a player, I want animated tileset tiles to cycle through their frames, so that the board feels alive.
2. As a player, I want all tiles of the same value to animate in sync, so that the display looks consistent.

## Implementation Decisions

- **`tileset.lua`** gains a `frame_index` (integer, starts at 0) and `advance()`. `advance()` increments `frame_index` modulo `frame_count`. `get_quad(value)` (frame argument dropped — frame is now internal state) returns the quad for the current frame.
- **`main.lua`** calls `tileset.advance()` each `love.update` call when a tileset is loaded.
- **`renderer.lua`** call sites drop the frame argument — no other changes needed.

## Testing Decisions

- Test that `advance()` wraps from `frame_count - 1` back to `0`.
- Test that a tileset with `frame_count = 1` stays at frame `0` after multiple `advance()` calls.

## Out of Scope

- Per-tile or per-value frame rates.
- Pausing animation when the game is in an overlay state.

## Further Notes

Because frame advancement happens every `love.update` (tied to Love2D's default 60 fps cap), a sheet with many frames will cycle quickly. This is intentional — the tileset author controls perceived speed by choosing how many frames to include. A config option for animation speed can be added later.
