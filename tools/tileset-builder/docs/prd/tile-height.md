---
title: "Tileset Builder: Independent Tile Height"
description: "tilesheet.py create always derives tile height from the first GIF's native aspect ratio, so there's no way to force a square (or otherwise custom) tile shape when the source GIFs aren't already that shape."
status: needs-triage
---

# Tileset Builder: Independent Tile Height

## Problem Statement

`tools/tileset-builder/tilesheet.py create` accepts `--tile-width`, but `tile_height` is always derived from the first GIF's (row 0's) native aspect ratio scaled to that width. There is no way to set tile height independently. Because of this, row 0 is implicitly exempt from ever needing `--shrink`/`--crop` — it always matches the derived tile aspect by construction, while rows 2+ may already need those flags if their aspect differs from row 0's. A theme author whose source GIFs are not square (or not the desired output aspect) cannot force a square — or any other specific — tile shape; the output tile shape is always dictated by whichever GIF happens to be listed first.

## Solution

Add an optional `--tile-height` flag to `tilesheet.py create`, alongside the existing `--tile-width`. When `--tile-height` is given, the derive-from-row-0-aspect step is skipped entirely and the given value is used directly — for both row 0 and every other row. This means row 0 is no longer special-cased: if its native aspect doesn't match the forced tile shape, it goes through the exact same `--shrink`/`--crop`/strict handling that already exists for every other row. Passing both `--tile-width` and `--tile-height` with equal values forces a square tile regardless of source GIF shapes. The existing `--shrink`/`--crop` flags are not changed in behavior — they simply now also apply to row 0 when relevant.

Strict-mode aspect mismatches (the default) currently raise a generic error with no indication of which GIF caused it; since row 0 can now fail this check (previously impossible), the error message is improved to name the offending GIF file.

## User Stories

1. As a theme author, I want to set an explicit tile height independent of the first GIF's aspect ratio, so that my output tileset isn't dictated by whichever GIF happens to be listed first.
2. As a theme author, I want to force a square tile shape by passing matching `--tile-width` and `--tile-height` values, so that the tileset renders consistently regardless of my source GIFs' native shapes.
3. As a theme author, I want to pass only `--tile-height` and have `--tile-width` default to row 0's native width, so that I can adjust one dimension without having to look up and re-specify the other.
4. As a theme author, I want `--shrink` and `--crop` to apply to row 0 the same way they already apply to every other row, so that forcing a tile shape that doesn't match my first GIF behaves consistently with how mismatches are already handled for later GIFs.
5. As a theme author, when a strict-mode aspect mismatch occurs, I want the error message to name the specific GIF file that caused it, so that I know which file to fix or which flag to add without trial and error.
6. As a developer, I want `create`'s behavior to be unchanged when `--tile-height` is omitted, so that all existing usage and tests of the tool keep working exactly as before.
7. As a developer, I want `append` to remain unaffected by this change, so that appending to an existing tilesheet continues to always use the dimensions already recorded in its `.lua` sidecar.

## Implementation Decisions

- **CLI**: `p_create` (the `create` subparser) gains a new optional `--tile-height` integer argument, parallel to the existing `--tile-width`. `append` and `inspect` are untouched — `append` always reads `tile_width`/`tile_height` from the target sheet's existing `.lua` sidecar, which is unrelated to this change.
- **`cmd_create` derivation logic**: today, `tile_h` is unconditionally computed as `round(native_h * tile_w / native_w)` from row 0's first frame. This becomes conditional: only derive `tile_h` this way when the caller didn't pass an explicit value. If `--tile-height` was given, that value is used as-is and the derivation step is skipped entirely. `tile_w` keeps its existing default-to-native-width behavior when `--tile-width` is omitted, independent of whether `--tile-height` was given.
- **No change needed in `scale_frame` / `build_sheet`**: these already process every row uniformly (strict/shrink/crop), including row 0. The only reason row 0 never previously exercised the mismatch path is that `tile_h` was always derived to fit it exactly. Once `tile_h` is allowed to come from the caller instead, row 0 mismatches surface through the exact same code path rows 2+ already use — no new mode-handling logic is needed.
- **Row-attributed error messages**: `build_sheet` iterates rows in the same order as the `gif_paths` list passed into `cmd_create`. When `scale_frame` raises on a strict-mode mismatch, `build_sheet` re-raises an error that carries the failing row index (rather than a bare `ValueError` with no positional context). `cmd_create` catches that row-indexed error and maps the row index back to the corresponding entry in `gif_paths`, producing a final user-facing message that names the specific GIF file (e.g. `error: tile_2.gif: frame aspect ratio 100x150 does not match tile 64x64; use --shrink or --crop`). `cmd_append`'s error path is unchanged — it already concerns exactly one GIF (the CLI argument itself), so the file is already unambiguous to the user without this change.
- **README**: `tools/tileset-builder/README.md`'s `create` usage section gains an example showing `--tile-width` and `--tile-height` together to force a square tile, and a short note that `--tile-height` (when given) is no longer derived from the first GIF's aspect ratio — meaning row 0 itself may now need `--shrink` or `--crop` if its native aspect doesn't match.

## Testing Decisions

- Tests live in `tools/tileset-builder/tests/test_tilesheet.py`, following the existing style (synthetic in-memory `Image` objects, no real GIF files), alongside the existing aspect-ratio and shrink/crop tests (`test_create_derives_tile_height_from_aspect_ratio`, `test_scale_frame_shrink_letterboxes_wide_frame`, `test_scale_frame_crop_fills_tile_no_transparency`, etc.).
- New `create`-level tests:
  - Explicit `--tile-height` overrides derivation: a non-square row-0 GIF with `--tile-width` and `--tile-height` both set produces a sheet whose tiles match the given (square) dimensions, not the derived aspect.
  - `--tile-height` given alone (no `--tile-width`): output tile width equals row 0's native width, height equals the given value.
  - Row 0 mismatch in strict mode (the new case — previously impossible) raises the same way a mismatched later row already does.
  - Row 0 mismatch with `--shrink` letterboxes/pillarboxes row 0 the same way it already does for later rows.
  - Row 0 mismatch with `--crop` fills row 0 with no transparency, same as later rows.
  - Omitting `--tile-height` entirely preserves all existing behavior (regression coverage — existing derivation tests should keep passing unmodified).
- New error-message test: a strict-mode mismatch on a specific GIF (by filename) produces an error message containing that filename, verified for both a row-0 mismatch and a later-row mismatch.
- No new tests needed for `append` or `inspect` — both are explicitly unaffected by this change.

## Out of Scope

- Any change to `append`'s behavior or CLI — it continues to always use the existing sheet's recorded `tile_width`/`tile_height` from its `.lua` sidecar, with no override flag.
- A `--square` convenience flag or other shorthand — `--tile-width N --tile-height N` already covers the square case directly.
- Validating that `--tile-width`/`--tile-height` are positive integers — consistent with today's lack of validation on `--tile-width`, this is not introduced here.
- Changes to `theme-builder` (still in triage) — that tool's design explicitly always calls `tilesheet.py create --crop` without exposing `--tile-width`/`--tile-height`; whether to expose this new flag through theme-builder is a separate decision for whoever triages that PRD.
- Re-deriving or migrating tile dimensions for already-built tilesheets — this only affects how a *new* sheet is built via `create`.

## Further Notes

This PRD was scoped during a grilling session that confirmed: (1) this extends the existing `tools/tileset-builder` tool rather than introducing a new tool, (2) `--shrink`/`--crop` already exist in the codebase and need no new flags — the gap was purely that row 0 was structurally exempt from ever needing them, and (3) the filename-in-error improvement is needed specifically because row 0 failing this check is a new possibility this PRD introduces, where previously only rows 2+ could ever fail it.
