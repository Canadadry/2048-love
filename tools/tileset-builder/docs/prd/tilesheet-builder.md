---
title: "Tilesheet Builder"
description: "No tooling exists to convert GIF animations into the PNG sprite sheet format expected by the tileset loader."
status: needs-triage
---

# Tilesheet Builder

## Problem Statement

No tooling exists to convert GIF animations into the PNG sprite sheet format expected by the tileset loader. Producing a valid tilesheet manually requires pixel-precise layout work and is error-prone.

## Solution

A Python CLI tool (`tools/tilesheet.py`) with two sub-commands: `create` builds a fresh tilesheet from a list of GIFs, `append` adds a new row to an existing one. Both commands produce a PNG sprite sheet and a companion `.lua` sidecar that the game reads to know the per-row frame counts.

## Tileset Format (recap from PRD 007)

- Single PNG, each row is one tile value, frames laid out left-to-right.
- `tile_size = image_height / row_count` (all frames are square).
- `frame_count` per row can differ; PNG width = `max(frame_count) * tile_size`.
- Shorter rows are padded with fully-transparent tiles on the right.

## User Stories

1. As a developer, I want to run a single command to turn a set of GIFs into a ready-to-use tilesheet PNG, so that I do not need to manually composite sprite sheets.
2. As a developer, I want to append a new GIF row to an existing tilesheet without rebuilding from scratch, so that I can add tile values incrementally.
3. As a developer, I want the tool to handle GIFs with different frame counts per row transparently, so that each tile value can have its own animation length.
4. As a developer, I want a companion `.lua` file generated alongside the PNG, so that the game renderer can read per-row frame counts without an extra parsing step.

## CLI Interface

```
# Create a fresh tilesheet (row order = argument order)
python tools/tilesheet.py create output.png --tile-size 64 row0.gif row1.gif ...

# Append one GIF as a new bottom row to an existing tilesheet
python tools/tilesheet.py append output.png new_row.gif
```

## Implementation Decisions

- **Language / dependency**: Python 3, Pillow only. No other third-party libraries.
- **Resampling**: bilinear (`Image.BILINEAR`) when scaling GIF frames to `tile_size × tile_size`.
- **Transparency**: GIF transparent color index is preserved as full alpha-0 in the RGBA output PNG. No background compositing.
- **PNG width**: always `max(frame_count_across_all_rows) * tile_size`. When `append` adds a row whose frame count exceeds the current width, all existing rows are re-composited onto a wider canvas with transparent padding on the right.
- **`create`**:
  1. Parse `--tile-size N` (required).
  2. For each GIF argument: extract all frames, scale each to `N × N` RGBA, record `frame_count`.
  3. Compute canvas: width = `max(frame_counts) * N`, height = `len(gifs) * N`.
  4. Paste frames row by row; pad shorter rows with transparent `N × N` tiles.
  5. Save PNG to `output.png`.
  6. Write `output.lua` (same stem, same directory).
- **`append`**:
  1. Derive sidecar path from PNG path (same stem, `.lua` extension).
  2. Read `tile_size` and `frame_counts` from the existing `.lua` sidecar.
  3. Extract and scale new GIF frames to `tile_size × tile_size` RGBA.
  4. If `new_frame_count > current_max_frames`: re-composite existing PNG onto a wider canvas first.
  5. Paste new row at `y = current_row_count * tile_size`.
  6. Save updated PNG and updated `.lua`.
- **`.lua` sidecar format**:
  ```lua
  return {
    tile_size = 64,
    frame_counts = { 4, 8, 3 },
  }
  ```
  One entry in `frame_counts` per row, in row order. Written with `io.write` / plain string formatting — no template engine needed.
- **Error handling**: exit with a clear message if `--tile-size` is missing on `create`, if the PNG/sidecar is missing on `append`, or if a GIF has zero frames.

## Testing Decisions

- Unit-test the core logic with synthetic in-memory `Image` objects (no real GIF files required):
  - `create` with two GIFs of unequal frame counts produces the correct canvas size.
  - `append` with a frame count larger than the current max expands the PNG width.
  - `append` with a frame count smaller than the current max does not shrink the PNG.
  - Transparent GIF pixels appear as alpha-0 in the output PNG.
- Tests live in `tests/test_tilesheet.py`, run with `pytest`.

## Out of Scope

- Reordering or deleting existing rows.
- Importing frame counts from the `.lua` back into a GIF.
- Animated WebP or APNG input formats.
- A `--fps` or frame-rate flag (frame count controls perceived speed, per PRD 008 design).

## Further Notes

The `.lua` sidecar is the source of truth for `tile_size` and `frame_counts` on `append`. The PNG dimensions are not parsed — they are derived from the sidecar to avoid floating-point rounding issues with integer tile sizes.
