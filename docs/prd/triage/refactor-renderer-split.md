---
title: "Refactor: Renderer Split"
description: "renderer.lua has grown into a shallow, hard-to-navigate module that mixes unrelated concerns after gaining tileset, HUD, and overlay responsibilities."
status: needs-triage
---

# Refactor: Renderer Split

## Problem Statement

After PRD 013, `renderer.lua` handles board background, individual tile drawing (classic and tileset), score HUD, and win/game-over overlays. It has grown into a shallow, hard-to-navigate module that mixes unrelated concerns.

## Solution

Split `renderer.lua` into four focused sub-modules under a `renderer/` directory. A thin `renderer/init.lua` orchestrates them. No behavioral changes.

## User Stories

1. As a developer, I want tile drawing logic isolated from board and HUD drawing, so that tileset changes only touch one file.
2. As a developer, I want overlay rendering isolated, so that adding new overlays (e.g. a pause screen) requires no changes to board or tile code.

## Implementation Decisions

- **`renderer/board.lua`** — draws the board background (rounded rectangle or plain rect per config) and empty cell slots.
- **`renderer/tile_draw.lua`** — draws a single tile given its position, value, scale, and active tileset (or nil for classic). Contains the classic color fallback logic and the `love.graphics.draw` quad path.
- **`renderer/hud.lua`** — draws the score display and any future HUD elements.
- **`renderer/overlay.lua`** — draws the You Win and Game Over overlays with their option labels.
- **`renderer/init.lua`** — requires the four sub-modules and exposes the same public interface as the original `renderer.lua` (`draw_board`, `draw_tiles`, `draw_hud`, `draw_overlay`). All callers outside `renderer/` remain unchanged.

The original `renderer.lua` file is deleted. All call sites import `renderer` (resolves to `renderer/init.lua` via Love2D's require path).

## Testing Decisions

- No new tests — this is a pure structural refactor. Existing behavior tests (if any) should continue passing without modification.
- Verify: after the split, running the game produces pixel-identical output to pre-split (manual check).

## Out of Scope

- Any behavioral changes to rendering.
- Shader or post-processing effects.

## Further Notes

`renderer/tile_draw.lua` is named to avoid collision with `tile.lua` (the animation state module) in Love2D's require namespace.
