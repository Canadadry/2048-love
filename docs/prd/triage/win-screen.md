---
title: "Win Screen"
description: "Migrate gamestate.lua's WinState onto the screen_manager stack as a standalone win_screen.lua module, owning its own win-particle effect."
status: needs-triage
---

# Win Screen

## Problem Statement

The win overlay currently lives as `WinState` inside `gamestate.lua`, sharing `ctx.win_particles` and `ctx.win_seen` with `PlayingState`. Per the parent [Screen Stack Refactor](screen-stack-refactor.md) PRD, this becomes a standalone `WinScreen`, promoted by [Game Screen](game-screen.md) onto the stack, holding a reference back to it rather than sharing a `ctx`.

## Solution

Add `game/screens/win_screen.lua`. It's promoted by `GameScreen` via `host:promote(make_win_screen(game))` once a move produces a win that hasn't been seen yet this game. It holds a reference to the promoting `GameScreen` (`game`) to call `restart()` and to mark the win as seen on Continue.

Per the parent PRD's decision, win particles become a **screen-local effect**: `WinScreen` owns its own particle list, spawning it in `enter()` (when `config.EFFECTS_ENABLED`) and updating/drawing it itself, rather than the board (`GameScreen`) tracking particle state that's really about this overlay's presentation.

`menu.lua`'s existing `win_tree` / `draw_win` / `win_hit_test` are reused unchanged.

## User Stories

1. As a player, reaching the win tile shows the same Win screen as today, with the board frozen and visible underneath the dimmed overlay.
2. As a player, I see the same particle celebration effect when Effects are enabled, and none when they're disabled, exactly as today.
3. As a player, pressing Down/Up moves the highlight between Continue and Restart, clamped at both ends.
4. As a player, pressing Enter on Continue dismisses the Win screen and lets me keep playing on the same board.
5. As a player, pressing Enter on Restart starts a fresh board and dismisses the Win screen.
6. As a player, tapping Continue or Restart directly does the same as pressing Enter on that option.
7. As a player, continuing past a win and reaching the same win tile again in the same game does not reopen the Win screen (this is enforced by `GameScreen`, not by this screen, but the Continue action must still mark that condition before dismissing).
8. As a developer, I want `WinScreen` constructed with a direct `game` reference (`WinScreen.new(host, game)`), not a factory — unlike `MainMenuScreen`'s `make_game_screen`, the `GameScreen` instance already exists and is live at the moment `WinScreen` is promoted, since it's the one doing the promoting (same relationship `pause_screen.lua` already has with its `game` parameter).
9. As a developer, I want win-particle spawn/update/cull logic to live entirely inside `win_screen.lua`, owning its own particle list rather than reading/writing a list on `GameScreen` — so `GameScreen` doesn't need to know anything about win-specific visual effects.
10. As a developer, I want `WinScreen`'s Continue action to call a method on `game` (e.g. `game:mark_win_seen()`) before dismissing, so `GameScreen` retains sole ownership of the "don't reopen Win this game" flag.
11. As a developer testing this screen, I want every behavior `tests/test_gamestate.lua`'s win-overlay tests currently exercise (Continue dismisses, win doesn't reappear after Continue, board state preserved across Continue, particles populated/empty per `EFFECTS_ENABLED`, particles individually expire by their own lifetimes) ported onto direct calls against `WinScreen`, driven with a stub `game`.
12. As a developer, I want `particle.lua` itself left completely unchanged — this PRD only relocates which module owns calling it.

## Implementation Decisions

- **`game/screens/win_screen.lua`**, interface: `M.new(host, game)`.
  - `host`: the `ScreenManager` instance.
  - `game`: the promoting `GameScreen` instance, exposing `restart()` and `mark_win_seen()`.
- **`enter()`**: resets cursor to 0; spawns `self._particles = config.EFFECTS_ENABLED and particle.spawn() or {}` — same condition as today's `WinState:enter()`, now writing to a screen-local field instead of `ctx.win_particles`.
- **`update(dt)`**: updates and culls `self._particles` (ticks each, drops dead ones) — the same logic as today's module-level `update_particles(ctx, dt)` helper in `gamestate.lua`, now scoped to this screen. `GameScreen` does not need its own particle update logic at all once this moves.
- **`cursor()`** (or equivalent accessor) exposes the 0/1 highlight state for `draw()` and tests.
- **`keypressed(key)`**: `up`/`down` move and clamp the cursor (0–1); `return` activates Continue (cursor 0) or Restart (cursor 1).
- **Continue action**: `game:mark_win_seen()`, then `host:dismiss()`. Does *not* clear `game`'s board state — Continuing keeps playing the same board, only suppressing future Win re-triggers this game.
- **Restart action**: `game:restart()`, then `host:dismiss()`.
- **`tap(x, y)`**: wraps `menu.win_hit_test(cursor, callbacks, x, y)`, with `on_continue`/`on_restart` callbacks each firing the same action as their corresponding Enter dispatch — mirrors `pause_screen.lua`'s `tap`.
- **`draw()`**: delegates to `menu.draw_win(cursor, self._particles)`.
- **`opaque()`**: returns `false` — the board must stay visible underneath, same reasoning as `pause_screen.lua`.

## Testing Decisions

- Tests assert observable behavior through the public screen interface, not internal particle/cursor representation — consistent with `tests/test_pause_screen.lua`.
- **`tests/test_win_screen.lua`**, driven against a stub host (`dismiss` spy) and a stub `game` (`restart`/`mark_win_seen` spies).
- Behaviors ported from `tests/test_gamestate.lua`'s win-related tests: Continue dismisses; win does not reappear after Continue (verified at the `GameScreen` level via `mark_win_seen` being called, not re-asserted here); Continue preserves board state (verified by *not* calling `restart`); cursor starts at 0 and moves between 0/1; entering with Effects enabled/disabled populates/empties particles correctly; particles individually expire by their own lifetimes rather than all at once (reuses `particle.lua`'s existing lifetime behavior, already covered by `tests/test_particle.lua`).
- `particle.lua`'s own unit tests (`tests/test_particle.lua`) are unaffected and untouched.
- `make test-game` must stay green throughout, one TDD cycle at a time, tracer bullet first.

## Out of Scope

- `game_screen.lua` itself — a separate sibling PRD; this PRD assumes a `game` object shaped like it (`restart()`, `mark_win_seen()`) is supplied by whoever constructs `WinScreen`.
- `particle.lua` internals.
- Any change to `menu.lua`'s `win_tree`/`draw_win`/`win_hit_test`.

## Further Notes

This PRD is a sibling to [Main Menu Screen](main-menu-screen.md), [Game Screen](game-screen.md), and [Game Over Screen](game-over-screen.md). It can be implemented before `game_screen.lua` exists, since its constructor takes a plain `game` reference rather than requiring the real module — tests simply stub an object with the two methods it needs.
