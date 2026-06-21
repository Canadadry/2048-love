---
title: "Tileset Animation"
description: "After PRD 003, tileset tiles are static — only the first frame is ever shown. Tilesets with multiple frames per row appear frozen."
status: done
---

# Tileset Animation (Frame Cycling)

## Problem Statement

After PRD 003, tileset tiles are static — only the first frame is ever shown. Tilesets with multiple frames per row appear frozen.

## Solution

Derive the active frame from elapsed time and a fixed frames-per-second rate, rather than a tick counter. All tiles in the same row share the same elapsed time, so the sheet animates uniformly.

## User Stories

1. As a player, I want animated tileset tiles to cycle through their frames, so that the board feels alive.
2. As a player, I want all tiles of the same value to animate in sync, so that the display looks consistent.

## Implementation Decisions

- **`tileset.lua`** gains `frame_at(frame_count, fps, time)`, which returns `floor(time * fps) % frame_count`.
- **`config.lua`** adds `TILESET_ANIM_FPS` (12) to control animation speed independent of the render framerate.
- **`renderer.lua`** tracks `anim_time` per render state, incrementing it by `dt` each frame, and calls `tileset.frame_at(frame_count, config.TILESET_ANIM_FPS, anim_time)` to pick the quad for each tile.

This differs from the original tick-counter design (`frame_index` + `advance()`): a time/fps-based approach decouples animation speed from Love2D's framerate, so the same tileset animates at the same perceived speed regardless of display refresh rate.

## Testing Decisions

- `tests/test_tileset.lua` covers `frame_at`: returns `0` at `time = 0`, advances one frame after `1/fps` seconds, wraps back to `0` after a full cycle, and always returns `0` for a single-frame tileset.

## Out of Scope

- Per-tile or per-value frame rates.
- Pausing animation when the game is in an overlay state.
