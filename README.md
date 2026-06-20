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
