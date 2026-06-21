---
title: "Theme Builder"
description: "Building a custom tileset from a set of Giphy GIFs requires manually running curl-giphy once per URL, then manually invoking tileset-builder on the downloaded files in the right order."
status: needs-triage
---

# Theme Builder

## Problem Statement

Building a custom tileset today is a manual, multi-step, error-prone process: the theme author opens `themes/<name>.txt`, copies each Giphy URL out one at a time, runs `make dl URL=...` repeatedly (each download lands in whatever the current directory happens to be), renames/collects the resulting GIFs in the right tile-value order, and then hand-builds the `tilesheet.py create` command line with all of them as positional arguments. There's no single command that turns a theme manifest into a ready-to-use tilesheet, and nothing enforces that the GIFs end up in the right row order or that mismatched aspect ratios are handled consistently.

## Solution

A new `tools/theme-builder` tool reads a `themes/<name>.txt` manifest — one Giphy URL per line, line order matching tile value order (2, 4, 8, ... up to 8192) — and produces `game/assets/<name>.png` plus its `.lua` sidecar in one command: `make theme NAME=<name>`.

The tool is pure orchestration glue over the two existing tools: it shells out to `curl-giphy`'s `giphy_dl.py` to download each URL (caching results under `themes/<name>/raw/` so reruns don't re-download unchanged GIFs), then shells out to `tileset-builder`'s `tilesheet.py create --crop` on the cached GIFs in manifest order. Neither existing tool is modified.

## User Stories

1. As a theme author, I want to list Giphy URLs in a plain text manifest, one per tile value, so that I don't need to write any code to define a new theme.
2. As a theme author, I want to run a single command to turn my manifest into a finished tilesheet, so that I don't have to manually chain two separate CLI tools.
3. As a theme author, I want the manifest's line order to directly determine which tile value each GIF becomes, so that the mapping is obvious from reading the file.
4. As a theme author, I want a clear error naming the failing URL and line number when a download fails, so that I can fix the manifest instead of getting a corrupt or partial tilesheet.
5. As a theme author, I want already-downloaded GIFs to be reused on a rerun, so that fixing one bad line in my manifest doesn't force me to re-download every other GIF from Giphy.
6. As a theme author, I want GIFs of different aspect ratios to be handled automatically (cropped to fit the tile), so that I don't have to pre-process source GIFs by hand before building a theme.
7. As a theme author, I want my manifest to be validated against the tileset format (at most 13 rows, in order), so that I get an error immediately instead of a tilesheet that silently doesn't load correctly in-game.
8. As a developer, I want the theme-builder tool to be a thin orchestration layer with no changes to curl-giphy or tileset-builder, so that each tool remains independently usable and independently tested.
9. As a developer, I want the new tool's own tests to run fully offline, so that `make test-all` doesn't depend on network access or real Giphy pages.
10. As a developer, I want the build output to land in `game/assets/`, so that it's consistent with the already-gitignored build-artifact convention used elsewhere in the project.

## Implementation Decisions

- **New tool: `tools/theme-builder`** — Python, structured like its siblings (`tools/curl-giphy`, `tools/tileset-builder`): a `build.py` entry point, `README.md`, `tests/`. No new third-party dependencies — it only needs the standard library (`subprocess`, `argparse`, `pathlib`) since it delegates all actual downloading and image work to the two existing tools.

- **Manifest format** — `themes/<name>.txt`, one Giphy URL per line. Blank lines are ignored. Non-blank line order maps 1:1 to the tileset row order: line 1 → tile value 2, line 2 → tile value 4, ... up to line 13 → tile value 8192 (matching the 13-row format from PRD 003). A manifest with more than 13 non-blank lines is a validation error. A manifest can have fewer than 13 lines (e.g. `jurassic-park.txt` has 11, covering 2 through 2048) — `tileset-builder` already pads/falls back correctly for tile values beyond what the sheet covers.

- **Orchestration flow** (`build_theme(manifest_path)`):
  1. Derive `<name>` from the manifest's basename (`themes/jurassic-park.txt` → `jurassic-park`).
  2. Parse and validate the manifest into an ordered list of URLs.
  3. Ensure `themes/<name>/raw/` exists.
  4. For each URL, in order: if the GIF's expected filename (derived the same way `curl-giphy`'s `extract_filename` already does) already exists in `themes/<name>/raw/`, skip downloading it. Otherwise invoke `giphy_dl.py` as a subprocess with `cwd=themes/<name>/raw/`, using that tool's own venv. Any failure (non-zero exit, exception) aborts the whole build immediately with an error identifying the offending URL and its line number in the manifest — no partial tilesheet is written.
  5. Once all GIFs are present, invoke `tilesheet.py create --crop --output game/assets/<name>.png` as a subprocess, passing the cached GIF paths in manifest order, using `tileset-builder`'s own venv.
  6. `tilesheet.py` writes `game/assets/<name>.png` and `game/assets/<name>.lua` as it already does for any `create` call — no new sidecar-writing logic needed in theme-builder.

- **Module shape** — favor a small number of deep, independently testable functions over one monolithic script:
  - `parse_manifest(path) -> list[str]` — pure function, no I/O side effects beyond reading the file. Encapsulates all manifest validation rules (blank-line skipping, 13-row cap, ordering). This is the highest-value module to keep deep and well-tested since it's where manifest format rules live.
  - `download_gif(url, raw_dir) -> Path` — wraps the `giphy_dl.py` subprocess call plus the skip-if-cached check. Returns the path to the (now-guaranteed-present) GIF, or raises on failure.
  - `build_sheet(gif_paths, output_path) -> None` — wraps the `tilesheet.py create --crop` subprocess call.
  - `build_theme(manifest_path) -> None` — top-level orchestration tying the above together; this is the only function `build.py`'s CLI entry point calls directly.

- **Caching** — `themes/<name>/raw/*.gif` is added to `.gitignore` (new entry, e.g. `themes/*/raw/`), matching how `game/assets/`, `output.png`, and `output.lua` are already gitignored as build artifacts.

- **CLI / Makefile** — new `make theme NAME=jurassic-park` target added to the root `Makefile`, calling `tools/theme-builder/build.py themes/$(NAME).txt` (mirroring the existing `make dl URL=...` and `cd tools/X && source .venv/bin/activate && ...` pattern used by the other two tools' targets).

- **Scope boundary vs. existing tools** — `curl-giphy` and `tileset-builder` are unmodified and remain independently usable for one-off downloads or hand-built tilesheets. `theme-builder` only ever rebuilds a theme fully from its manifest; it does not expose `tileset-builder`'s `append` subcommand.

- **README updates** — root `README.md` gains a `theme-builder` entry under `## Tools` (describing `make theme NAME=...`), a `themes/` line under `## Structure`, and a `make test-tool-theme` line under `## Test`.

## Testing Decisions

- Tests are fully offline and never invoke the real `giphy_dl.py` or `tilesheet.py` processes — `subprocess.run` is mocked throughout, following the same `unittest.mock.patch` style already used in `tools/curl-giphy/test_giphy_dl.py`. Tests assert that theme-builder calls the right script with the right arguments and `cwd`, not on real downloads or real image output.
- `parse_manifest` is tested as a pure function: correct row-to-value mapping, blank lines ignored, error on >13 non-blank lines, error on empty manifest.
- `download_gif` is tested with a mocked subprocess: skips invoking the subprocess when the target file already exists in the cache dir; invokes it with the expected `cwd` when the file is missing; propagates failure (raises) when the subprocess exits non-zero.
- `build_sheet` is tested with a mocked subprocess: asserts the `tilesheet.py create --crop --output ... <gifs in order>` invocation shape.
- `build_theme` orchestration is tested end-to-end against mocked `download_gif`/`build_sheet` to verify the abort-on-first-failure behavior and that a failing line's URL/line number appears in the raised error.
- New `make test-tool-theme` Makefile target runs these tests (mirroring `test-tool-tileset` / `test-tool-dl`), folded into `make test-all`.

## Out of Scope

- Modifying `curl-giphy` or `tileset-builder` in any way.
- Supporting `tileset-builder`'s `append` subcommand from theme-builder (no per-row append workflow; editing the manifest and rebuilding is the only supported flow).
- A `--force` flag to bypass the raw-GIF cache (can be added later if needed; deleting `themes/<name>/raw/` by hand works as a manual escape hatch).
- Exposing `tilesheet.py`'s `--tile-width` override or `--shrink`/`--strict` scaling modes — theme-builder always uses `--crop`.
- Resolving the existing inconsistency in the unimplemented `tileset-picker` triage PRD, which references a `tilesets/` folder rather than `game/assets/` (see Further Notes).
- Any in-game UI for selecting between multiple built themes (covered separately by the `tileset-picker` triage PRD).

## Further Notes

- `themes/jurassic-park.txt` (already present, untracked) is the first real manifest and exercises the common case: 11 URLs, covering tile values 2 through 2048 exactly, with values above 2048 falling back to classic color rendering per PRD 003.
- The triage PRD `tileset-picker.md` currently describes scanning a `tilesets/` folder at the game root for available themes, but `game/assets/` is the actual gitignored build-output convention this tool (and the existing `.gitignore`) already use. Whoever triages `tileset-picker` next should reconcile that folder name before implementing it.
- `giphy_dl.py`'s existing filename derivation (`extract_filename`, slug-based from the URL path) is reused as-is to compute the expected cache filename in `download_gif` — no new naming scheme is introduced.
