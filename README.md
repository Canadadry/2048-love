# 2048

A Love2D implementation of the 2048 puzzle game.

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
```
