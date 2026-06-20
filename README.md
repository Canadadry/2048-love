# 2048

A Love2D implementation of the 2048 puzzle game — designed to run with animated GIF tilesets so every tile value can display a custom sprite animation instead of a plain colored square.

![Screenshot](docs/screen1.png)

## Requirements

- [LÖVE](https://love2d.org/) 11.x

## Play

```
make run
```

Arrow keys to slide tiles. Press `Escape` to quit. The window is resizable.

## Test

```
make test
```

Runs the pure-Lua test suite for the game logic (no Love2D runtime needed).

## Structure

```
game/           Love2D game source
  main.lua      entry point (Love2D callbacks)
  config.lua    constants and tile color map
  gamestate.lua score tracking and input routing
  renderer.lua  board drawing
  grid.lua      game logic — slide, merge, spawn, win/lose detection
tests/
  test_grid.lua test suite for grid.lua (plain lua)
docs/prd/       product requirements
tools/          helper CLI tools (see below)
```

## PRD Roadmap

Recommended implementation order for triage PRDs:

| # | PRD | Notes |
|---|-----|-------|
| 004 | game-states (Win & Game Over overlays) | Completes core game loop; no unmet dependencies. Renderer already draws partial overlays — just needs keyboard nav and Continue path in gamestate.lua. |
| 005 | merge-effect | Pure visual add; `merged` flag already in tile data from slide animation. |
| 006 | main-menu | Needs game-states first (New Game → clean playing state). |
| 007 | refactor-state-machine | Do before adding Options screen or you refactor into a moving target. |
| 008 | tileset-animation | Already unblocked (tileset-loading done). Can slot in anywhere before options. |
| 009 | options-screen-shell | Needs state machine as infrastructure. |
| 010+ | tileset-picker · animation-effect-toggles · settings-persistence | All need options screen first. |
| — | sound-hooks · refactor-renderer-split | Independent; pick up when the time feels right. |

**Flag:** `touch-swipe` is in triage but `swipe.lua` is already wired in `main.lua`. Verify before triaging — it may already be done.

## Tools

### curl-giphy

Downloads a GIF from a Giphy page URL and saves it to the current directory.

```
make dl URL=https://giphy.com/gifs/<slug>
```

### tileset-builder

Converts a set of GIFs into a PNG sprite sheet compatible with the game's tileset loader. Each GIF becomes one row (one tile value); animation frames are preserved.

```sh
cd tools/tileset-builder
source .venv/bin/activate
python tilesheet.py create tile_2.gif tile_4.gif tile_8.gif ...
```

See `tools/tileset-builder/README.md` for the full usage and output format.
