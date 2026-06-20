Status: needs-triage

# PRD 007 — Tileset Loading (Static, First Frame)

## Problem Statement

Classic color rendering is the only visual style. Players cannot customise the look of their tiles.

## Solution

Load a tileset PNG from a configurable path and render each tile value from the corresponding sprite sheet row. Only the first animation frame is used in this PRD — frame cycling comes in PRD 008.

## Tileset Format

A single PNG file laid out as a sprite sheet:
- **13 rows**, one per tile value in order: 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192.
- Each row is a horizontal strip of square frames. `tile_size = image_height / 13`. `frame_count = image_width / tile_size`.
- All frames are the same size. The sheet need not be square.
- For tiles with value > 8192, fall back to classic color rendering.

## User Stories

1. As a player, I want my tiles to display as custom graphics when a tileset is configured, so that I can personalise the game's appearance.
2. As a player, I want the tile value number hidden when a tileset is active, so that graphics are not obscured by text.
3. As a player, I want tiles beyond 8192 to still render (using classic colors) if the tileset doesn't cover them, so that the game remains playable after extreme merges.
4. As a developer, I want to set the tileset path in `config.lua` with `nil` meaning classic colors, so that the default experience requires no file.

## Implementation Decisions

- **`tileset.lua`** — new deep module. `load(path)` opens the PNG, computes `tile_size` and `frame_count`, builds a `love.graphics.Quad` table indexed by tile value. `get_quad(value, frame)` returns the quad or `nil` if the value is out of range. No Love2D state is kept between frames beyond the `Image` and `Quad` table.
- **`renderer.lua`** — when a tileset is active, draws tiles via `love.graphics.draw(image, quad, ...)` instead of filled rectangles. No value text is drawn. Falls back to classic color drawing when `get_quad()` returns `nil`.
- **`config.lua`** gains `TILESET_PATH = nil`. Setting it to a relative path (e.g. `"tilesets/default.png"`) activates the tileset.
- `tileset.lua` is loaded once in `main.lua` at startup if `TILESET_PATH` is set.

## Testing Decisions

`tileset.lua` is the test target — it is a pure data-transformation module (given an image dimension, produce quads) with no rendering side effects.

- Test that `tile_size` is computed correctly from a known image height.
- Test that `get_quad(2, 0)` returns the quad for row 0 (first row).
- Test that `get_quad(8192, 0)` returns the quad for row 12 (last row).
- Test that `get_quad(16384, 0)` returns `nil`.

Note: tests use a mock `love.graphics` that returns a stub image with known dimensions — no actual PNG required.

## Out of Scope

- Frame animation (PRD 008).
- Tileset selection UI (PRD 010).
- Hot-reloading the tileset at runtime.

## Further Notes

The quad table is keyed by tile value (2, 4, 8, …) not by row index, to avoid off-by-one errors at call sites.
