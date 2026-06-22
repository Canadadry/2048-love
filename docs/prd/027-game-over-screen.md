---
title: "Game Over Screen"
description: "Migrate gamestate.lua's GameOverState onto the screen_manager stack as a standalone game_over_screen.lua module."
status: done
---

# Game Over Screen

## Problem Statement

The game-over overlay currently lives as `GameOverState` inside `gamestate.lua`, sharing `ctx` with `PlayingState`. Per the parent [Screen Stack Refactor](screen-stack-refactor.md) PRD, this becomes a standalone `GameOverScreen`, promoted by [Game Screen](game-screen.md) onto the stack, holding a reference back to it. This is the simplest of the four remaining screens — no cursor, a single action.

## Solution

Add `game/screens/game_over_screen.lua`. It's promoted by `GameScreen` via `host:promote(make_game_over_screen(game))` once a move leaves no legal moves in any direction. It holds a reference to the promoting `GameScreen` (`game`) to call `restart()`.

`menu.lua`'s existing `game_over_tree` / `draw_game_over` / `game_over_hit_test` are reused unchanged.

## User Stories

1. As a player, running out of legal moves shows the same Game Over screen as today, with the board frozen and visible underneath the dimmed overlay.
2. As a player, pressing Enter restarts with a fresh board.
3. As a player, pressing any arrow key also restarts (matching today's `GameOverState:keypressed`, which treats Enter and all four direction keys identically).
4. As a player, tapping the Restart button does the same as pressing Enter.
5. As a developer, I want `GameOverScreen` constructed with a direct `game` reference (`GameOverScreen.new(host, game)`), not a factory — the `GameScreen` instance already exists and is live at the moment this screen is promoted, the same relationship `win_screen.lua` has with its `game` parameter.
6. As a developer, I want this screen's logic kept minimal — no cursor, no state beyond the references it's constructed with — since the only action available is Restart, reachable from either a keypress or a tap.
7. As a developer testing this screen, I want every behavior `tests/test_gamestate.lua`'s game-over tests currently exercise (Enter restarts, any arrow key restarts) ported onto direct calls against `GameOverScreen`, driven with a stub `game`.

## Implementation Decisions

- **`game/screens/game_over_screen.lua`**, interface: `M.new(host, game)`.
  - `host`: the `ScreenManager` instance.
  - `game`: the promoting `GameScreen` instance, exposing `restart()`.
- **`keypressed(key)`**: if `key == "return"` or `key` is one of `left`/`right`/`up`/`down`, call `game:restart()` then `host:dismiss()` — same dispatch as today's `GameOverState:keypressed`.
- **`tap(x, y)`**: wraps `menu.game_over_hit_test(callbacks, x, y)`, with `on_restart` firing the same restart action.
- **`draw()`**: delegates to `menu.draw_game_over()`.
- **`opaque()`**: returns `false` — the board must stay visible underneath, same reasoning as `pause_screen.lua`/`win_screen.lua`.

## Testing Decisions

- Tests assert observable behavior through the public screen interface, not internal state (there is essentially none) — consistent with `tests/test_pause_screen.lua`/`tests/test_win_screen.lua`.
- **`tests/test_game_over_screen.lua`**, driven against a stub host (`dismiss` spy) and a stub `game` (`restart` spy).
- Behaviors ported from `tests/test_gamestate.lua`'s game-over tests: pressing Enter restarts; pressing an arrow key restarts; tapping the Restart button restarts; a miss tap does nothing.
- `make test-game` must stay green throughout, one TDD cycle at a time, tracer bullet first.

## Out of Scope

- `game_screen.lua` itself — a separate sibling PRD; this PRD assumes a `game` object shaped like it (`restart()`) is supplied by whoever constructs `GameOverScreen`.
- Any change to `menu.lua`'s `game_over_tree`/`draw_game_over`/`game_over_hit_test`.

## Further Notes

This PRD is a sibling to [Main Menu Screen](main-menu-screen.md), [Game Screen](game-screen.md), and [Win Screen](win-screen.md). Given how small this screen is, it's a reasonable candidate to implement first or as a quick follow-up immediately after `win_screen.lua`, since the two share nearly identical structure (direct `game` reference, `opaque() == false`, reuse of an existing `menu.lua` tree/hit-test).
