---
title: "Refactor: Renderer Split"
description: "renderer.lua has grown into a shallow, hard-to-navigate module that mixes unrelated concerns after gaining tileset, HUD, and overlay responsibilities."
status: done
---

# Refactor: Renderer Split

## Problem Statement

After PRD 013, `renderer.lua` handles board background, individual tile drawing (classic and tileset), score HUD, and win/game-over overlays. It has grown into a shallow, hard-to-navigate module that mixes unrelated concerns.

## Solution

Split `renderer.lua` into focused sub-modules under a `renderer/` directory. A thin `renderer/init.lua` orchestrates them. No behavioral changes.

## User Stories

1. As a developer, I want tile drawing logic isolated from board and HUD drawing, so that tileset changes only touch one file.

## Implementation Decisions

By the time this was picked up, overlay rendering (You Win, Game Over, Pause, Main Menu, Options) already lived entirely in `menu.lua` — there was nothing overlay-related left in `renderer.lua` to extract. The split below reflects what was actually mixed in `renderer.lua`: tileset/quad state, board geometry, tile drawing, and score HUD positioning.

- **`renderer/board.lua`** — board geometry (`metrics`, `cell_to_px`) and `draw_background`.
- **`renderer/tile_draw.lua`** — tileset/quad loading state (`set_tileset`, `update`) and per-tile drawing (`tile_color`, `draw`), covering both the classic color fallback and the tileset quad path.
- **`renderer/hud.lua`** — score position (`score_position`) and `draw`.
- **`renderer/init.lua`** — requires the three sub-modules and exposes the same public interface as the original `renderer.lua` (`load`, `update`, `draw`, `set_tileset`). All callers outside `renderer/` remain unchanged — `main.lua` still does `require("renderer")`, which resolves to `renderer/init.lua` via Lua's `?/init.lua` search path.

The original `renderer.lua` file is deleted.

## Testing Decisions

- Added pure-logic tests for the extracted, graphics-free functions (`board.metrics`, `board.cell_to_px`, `tile_draw.tile_color`, `hud.score_position`) — same style as the existing `*_bounds()` tests in `test_menu.lua`.
- No tests for the `draw()` orchestration itself or other functions that call `love.graphics.*` directly — the test harness doesn't stub those calls.

## Out of Scope

- Any behavioral changes to rendering.
- Shader or post-processing effects.
- Touching `menu.lua` (overlay rendering already lives there; out of scope for this refactor).

## Further Notes

`renderer/tile_draw.lua` is named to avoid collision with `tile.lua` (the animation state module) in Love2D's require namespace.
