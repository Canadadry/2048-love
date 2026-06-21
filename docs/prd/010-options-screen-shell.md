---
title: "Options Screen Shell"
description: "There was no way to access settings from within the game. This adds an Options screen reachable from the main menu, including a first real control: a Win Tile (dev/prod) toggle."
status: done
---

# Options Screen Shell

## Problem Statement

There was no way to access settings from within the game. The board's win threshold could only be changed via the `--win-tile` CLI flag at launch.

## Solution

Add an Options screen reachable from the main menu. It is wired into the state machine as its own `options.lua` module, navigated back to the main menu with Escape. It hosts a Win Tile control toggling the win threshold between `32` (dev) and `2048` (prod) without restarting the game.

## User Stories

1. As a player, I want an Options entry in the main menu, so that I can reach settings without editing config files.
2. As a player, I want to press Escape from the Options screen to return to the main menu, so that navigation is consistent.
3. As a developer, I want the Options screen to be a proper state machine state, so that adding more controls later requires no structural changes.
4. As a developer, I want to flip between the dev (`32`) and prod (`2048`) win thresholds from inside a running game, so I can test win/game-over flows without relaunching with a CLI flag.

## Implementation Decisions

- **`options.lua`** — new state module exporting `M.new(ctx, Base)`. It receives the shared `Base` prototype from `gamestate.lua` (rather than duplicating its query-method defaults) so it gets the same fallbacks (`score()`, `cells()`, etc.) as every other state.
- **`gamestate.lua`**'s `Base` gains `in_options()` (default `false`, overridden by `OptionsState`) and `win_tile()` (returns `config.WIN_TILE` — shared by all states since it's a global setting, not per-state).
- **`MenuState`** cursor now spans 3 items: New Game (0), Options (1), Quit (2); clamp range updated from 1 to 2.
- **`OptionsState:keypressed`** handles `escape` (`ctx.switch("menu")`) and `left`/`right` (toggles `config.WIN_TILE` between `2048` and `32`). `grid.lua` already reads `config.WIN_TILE` fresh on every move, so the toggle takes effect immediately with no further plumbing.
- **`menu.lua`** gains a third main-menu button ("Options", between "New Game" and "Quit") and `draw_options(win_tile)`, rendering the current Win Tile value with a "Left/Right to change" hint.
- **`main.lua`** wires the `love.draw` options branch and extends the main-menu tap handler for the third button; the pause icon is suppressed while `in_options()`.

## Testing Decisions

- `tests/test_main_menu.lua` updated for the 3-item cursor (Options between New Game and Quit), including the new clamp bound and the Options-switch behavior on Enter.
- `tests/test_options.lua` (new) covers: Escape from Options returns to the menu; `win_tile()` defaults to `2048`; Left/Right toggles between `2048` and `32`.

## Out of Scope

- Tileset selection, animation-effect toggles, settings persistence across launches (future PRDs).
- A rendered back button (Escape-only navigation is sufficient).

## Further Notes

`OptionsState` calls `ctx.switch("menu")` on Escape — it does not push/pop, since the state machine is a single-slot switcher (see PRD 008).
