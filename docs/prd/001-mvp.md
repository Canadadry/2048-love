Status: needs-triage

# PRD 001 — MVP: Playable 2048

## Problem Statement

There is no game. A player who wants to play 2048 has nothing to run.

## Solution

A minimal playable 2048 on a 4×4 grid with classic color-coded tiles, arrow-key input, and a live score display. The window starts at 800×600 and is resizable — the board scales to fit. When a win or loss condition is reached, the game simply freezes (no overlay yet — that comes in PRD 002).

## User Stories

1. As a player, I want to launch the game and see a 4×4 board with two starting tiles, so that I can begin playing immediately.
2. As a player, I want to press arrow keys to slide all tiles in a direction, so that I can make moves.
3. As a player, I want tiles with the same value that collide to merge into one tile with double the value, so that I can build higher tiles.
4. As a player, I want a new tile (value 2 or 4) to spawn in a random empty cell after each move, so that the board evolves over time.
5. As a player, I want each tile to be color-coded by value (e.g. cream for 2, orange for 64, deep red for 512), so that I can read the board at a glance.
6. As a player, I want the tile value printed on each tile, so that I can see exact numbers without counting merges.
7. As a player, I want a score counter that increments by the value of each merged tile, so that I can track my progress.
8. As a player, I want the board to fill the window proportionally when I resize it, so that I can play comfortably at any window size.
9. As a player, I want the game to accept no input once no moves remain, so that the frozen state signals the game is over (before overlays are added).

## Implementation Decisions

- **`config.lua`** — static constants: grid size (4), starting window dimensions (800×600), tile color map (value → background color and text color), spawn probabilities (90% chance of 2, 10% chance of 4).
- **`grid.lua`** — deep module with no Love2D dependency. Owns the board as a 2D array of integers (0 = empty). Exposes: `new()`, `move(direction)` → returns `{moved, score_delta, win, game_over}`, `spawn_tile()`, `get_cells()`. All game logic lives here and nowhere else.
- **`renderer.lua`** — reads grid cells and draws colored rectangles with centered value text. Computes tile size and board offset from current window dimensions on every draw call so resize is automatic.
- **`gamestate.lua`** — single state `playing`. Holds the grid instance and current score. Routes input to grid, accumulates score.
- **`main.lua`** — wires Love2D callbacks (`load`, `update`, `draw`, `keypressed`, `resize`) to gamestate and renderer. No logic here.

Tile color map lives in `config.lua` as a plain table keyed by tile value. Unknown values (not in the map) use a default dark color.

## Testing Decisions

Good tests verify observable output for a given input — they do not inspect internal data structures or call private helpers.

**`grid.lua` is the primary test target** — it is a pure Lua module with no Love2D calls, so tests run with plain `lua` or `busted` without a Love2D runtime.

Tests to write:
- Moving in each direction on a known board produces the correct resulting board.
- Two tiles of equal value that collide merge into one tile of double the value.
- A merge produces the correct score delta.
- A tile does not merge twice in one move.
- After a valid move, `spawn_tile()` places a tile (2 or 4) in a previously empty cell.
- `move()` returns `moved = false` when no tile changes position.
- `move()` returns `game_over = true` when no legal move exists in any direction.
- `move()` returns `win = true` when a 2048 tile is produced.

## Out of Scope

- Win / Game Over overlays (PRD 002)
- Animations (PRD 003, 004)
- Main menu (PRD 005)
- Tileset rendering (PRD 007)
- Sound (PRD 013)
- Settings persistence (PRD 012)

## Further Notes

The board scaling approach: derive `tile_size = math.floor(math.min(window_w, window_h) * 0.8 / 4)` each draw call. Board is centered in the window. No cached pixel values — everything is recomputed from current dimensions.

Spawn probability: 90% chance of 2, 10% chance of 4, matching the original game.
