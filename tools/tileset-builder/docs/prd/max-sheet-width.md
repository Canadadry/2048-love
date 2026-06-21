---
title: "Tileset Builder: Max Sheet Width Guard"
description: "tilesheet.py builds sheets wide enough to fit every row's full frame count at the chosen tile width, with no ceiling — a GIF with enough frames can produce a sheet wider than any GPU's max texture size, which only surfaces as a crash at game launch."
status: done
---

# Tileset Builder: Max Sheet Width Guard

## Problem Statement

`tools/tileset-builder/tilesheet.py create` lays out each row as `frame_count * tile_w` pixels wide and sizes the sheet's total width to the widest row. Nothing caps that width. The `jurassic-park` theme's manifest includes a GIF with 113 frames; at the theme-builder default of 256px tiles, that row alone is 28928px wide — past the 16384px texture-size ceiling most GPUs enforce. The game only discovers this at launch, via an `assert` in `game/tileset.lua` that aborts loading with a message telling the player to "rebuild it with a smaller --tile-width/--tile-height or fewer frames" — but nothing in the build tool itself prevents or even warns about this when the sheet is built. A theme author has no way to know their theme is broken until someone tries to load it in-game.

## Solution

`tilesheet.py` gains a built-in ceiling, `MAX_SHEET_WIDTH = 16384`, matching the common GPU texture-size floor. Both `create` and `append` check each row's frame count against this ceiling (given the sheet's tile width) and, when a row would exceed it, downsample that row's frames via even-stride sampling — keeping frames spread across the whole original clip rather than truncating to its start — until it fits. Each downsampled row prints a notice naming the source GIF and the before/after frame count. The `.lua` sidecar's `frame_counts` reflects the post-downsample counts, so playback (`tileset.frame_at`, fixed at `TILESET_ANIM_FPS`) is consistent with what was actually written to the sheet.

This is a build-time guard layered in front of the existing runtime `assert` in `game/tileset.lua`, which stays as-is for defense in depth (hand-built sheets that bypass `tilesheet.py`, or a GPU with a lower limit than 16384).

## User Stories

1. As a theme author, I want `tilesheet.py create` to automatically shrink an oversized row's frame count instead of silently producing a sheet that crashes the game at launch, so that I find out about and recover from the problem at build time.
2. As a theme author, I want the downsampled frames to be spread evenly across the original clip rather than just the first N frames, so that the animation still shows the whole loop, just choppier.
3. As a theme author, I want a clear message naming which GIF was downsampled and by how much, so that I know my theme's quality was reduced and which row to look at if I want to fix it (e.g. by trimming the source GIF myself).
4. As a theme author, I want `tilesheet.py append` to enforce the same width ceiling on the row I'm adding, so that appending to an existing sheet can't blow it past the texture-size limit either.
5. As a theme author, I want a clear error (not a malformed sheet) if my tile width alone already exceeds the max sheet width, so that I'm not left with a row that has zero frames.
6. As a developer, I want the existing runtime assert in `game/tileset.lua` to remain unchanged, so that sheets built outside this tool (or hand-edited) are still caught before they crash less gracefully inside `love.graphics.newImage`.
7. As a developer, I want `theme-builder` to need no code changes, so that it continues to be a thin orchestration layer that benefits from this guard automatically by virtue of shelling out to `tilesheet.py create`.
8. As a developer, I want the downsampling logic isolated in a pure function, so that it can be unit-tested without constructing real images or GIFs.

## Implementation Decisions

- **New constant**: `MAX_SHEET_WIDTH = 16384` at module level in `tilesheet.py`, documented inline as matching the common GPU texture-size floor (the same number the runtime assert in `game/tileset.lua` already names in its error message).
- **New pure function**: `downsample_frames(frames: list, limit: int) -> list`. Given a list (of any element type — frames, or anything else, it doesn't need to know about images) and a max length, returns an evenly-strided subset of length `<= limit`: `stride = ceil(len(frames) / limit)`, keep indices `0, stride, 2*stride, ...`. Returns the input unchanged (same list, or an equal copy) when `len(frames) <= limit`. This function has no dependency on PIL or any I/O — it operates on a generic list.
- **`cmd_create` changes**: after `tile_w`/`tile_h` are resolved (existing derivation logic for `--tile-width`/`--tile-height` is unchanged), compute `limit = MAX_SHEET_WIDTH // tile_w` once. For each row, if `len(frames) > limit`, replace it with `downsample_frames(frames, limit)` and print a notice: `row <idx> (<gif filename>): downsampled <old_count> -> <new_count> frames to fit <MAX_SHEET_WIDTH>px max sheet width`. The (possibly downsampled) rows are what `build_sheet` and `write_sidecar` both receive — `write_sidecar`'s existing `[len(r) for r in rows]` naturally reflects the new counts with no further change needed there.
- **`cmd_append` changes**: after reading `tile_w` from the existing sheet's `.lua` sidecar (existing `read_sidecar` call, unchanged), compute the same `limit = MAX_SHEET_WIDTH // tile_w` and apply `downsample_frames` to the new GIF's extracted frames before calling `append_row`, printing the same style of notice when triggered. `frame_counts.append(len(frames))` (existing line) naturally uses the downsampled length since it runs after the downsampling step.
- **Zero-fit edge case**: if `tile_w > MAX_SHEET_WIDTH` (i.e. `limit < 1`, meaning not even one frame fits), `cmd_create`/`cmd_append` exit immediately with a clear error (`sys.exit`, matching the tool's existing error style) naming the tile width and the max — downsampling cannot help here since a row needs at least 1 frame.
- **No changes to `theme-builder`**: it already shells out to `tilesheet.py create --crop`, so it inherits this guard automatically. No new flag is exposed through it (consistent with the existing scope boundary documented in `tools/theme-builder/docs/prd/theme-builder.md`, which already excludes exposing `tilesheet.py`'s tile-dimension flags).
- **No changes to `scale_frame`/`build_sheet`/`append_row`**: these continue to operate on whatever row lists they're given; they have no knowledge of the width ceiling, downsampling, or the limit — that logic lives entirely in `cmd_create`/`cmd_append` before these functions are called.
- **jurassic-park rebuild**: once this lands, regenerating the theme (`make theme NAME=jurassic-park`) will downsample row 4 (`vidiots-official-j3UvM5NaCV6HKRLqPy.gif`, 113 frames) to fit and produce a loadable sheet, with no manual tile-size override needed. `game/assets/jurassic-park.png`/`.lua` are gitignored build artifacts, so this is a local regeneration step, not a tracked-file change.

## Testing Decisions

- Tests live in `tools/tileset-builder/tests/test_tilesheet.py`, following the existing style (synthetic in-memory data, no real GIF files).
- **`downsample_frames` pure-function tests** (no images needed — plain lists of integers/sentinels suffice):
  - No-op when `len(frames) <= limit` (returns all frames, unchanged order).
  - Stride sampling reduces a frame list to exactly `limit` or fewer frames, e.g. a case shaped like the real `113 -> limit` scenario.
  - Always keeps frame index `0`.
  - `limit == 1` returns a single frame.
  - Exact-multiple and non-exact-multiple frame counts relative to the stride both produce a result `<= limit`.
- **`cmd_create` integration tests** (synthetic in-memory `Image` objects, mirroring existing tests like `test_create_derives_tile_height_from_aspect_ratio`):
  - A row whose frame count exceeds `MAX_SHEET_WIDTH // tile_w` is downsampled in the final sheet: assert the output image width and the written sidecar's `frame_counts` entry both reflect the post-downsample count.
  - A row within the limit is untouched (regression coverage for the common case, including existing tests that build small sheets).
  - The downsample notice is printed to stdout, naming the correct GIF filename and old/new counts (capture stdout, assert on content).
  - `tile_w > MAX_SHEET_WIDTH` exits with a clear error and writes no output files.
- **`cmd_append` integration tests**, same shape as `cmd_create`'s but for the single-row append path: appended row gets downsampled when it would exceed the limit given the sheet's existing `tile_w`; sidecar's appended `frame_counts` entry reflects the new count; notice is printed.
- No changes needed to `tools/theme-builder/tests/test_build.py` — `theme-builder`'s tests mock the `tilesheet.py` subprocess call entirely and don't exercise its internals.

## Out of Scope

- Changing `MAX_SHEET_WIDTH` into a CLI flag — it's a hardcoded constant; the runtime assert in `game/tileset.lua` remains the actual GPU-accurate check.
- Any change to `theme-builder` — it inherits the guard automatically with zero code changes.
- Removing or modifying the existing runtime assert in `game/tileset.lua` — it stays as defense-in-depth.
- Preserving original GIF frame timing/delays during downsampling — the build pipeline already discards per-frame GIF delays and plays every row back at a single fixed `TILESET_ANIM_FPS` (see PRD 004), so downsampling further shortens the loop the same way reducing source frame count always has.
- A way to cap or warn on frame count independent of sheet width (e.g. a max-frames-per-row flag unrelated to the texture-size ceiling) — only the width ceiling that actually causes a crash is addressed here.
- Re-processing or migrating already-built sheets — this only changes how a *new* `create`/`append` call behaves.

## Further Notes

This PRD was scoped during a grilling session triggered by a live crash: `game/tileset.lua:53`'s assert (itself a recent, uncommitted addition) firing on `jurassic-park` with `image is 28928x2816 but this GPU's max texture size is 16384`. The session confirmed: (1) the fix belongs in `tilesheet.py` itself rather than `theme-builder`, since `tileset-builder` is the lower-level tool used standalone too and is the one that actually knows the final sheet width; (2) downsampling (not just shrinking tile size) was the user's preferred remedy, since it preserves tile quality and only thins out the one pathological row; (3) even-stride sampling across the whole clip was chosen over truncating to the first N frames.
