---
title: "Main Menu Screen"
description: "Migrate gamestate.lua's MenuState onto the new screen_manager stack as a standalone main_menu_screen.lua module."
status: needs-triage
---

# Main Menu Screen

## Problem Statement

The main menu currently lives as `MenuState` inside `gamestate.lua`, sharing the same `ctx` table and `Base` mixin as every other state, and is driven by `statemachine.lua`'s single-slot `switch()`. Per the parent [Screen Stack Refactor](screen-stack-refactor.md) PRD, `gamestate.lua` and `statemachine.lua` are being retired in favor of `screen_manager.lua` and `game/screens/*`. `screen_manager.lua`, `options_screen.lua`, and `pause_screen.lua` already exist and are fully tested; the Main Menu screen is next.

## Solution

Add `game/screens/main_menu_screen.lua`, a screen module that owns the main menu's cursor and dispatches its three actions through the host (`ScreenManager`) instead of `ctx.switch`:

- **New Game** → `host:replace(make_game_screen())` — always builds a *fresh* `GameScreen`, never reuses one. This preserves a subtle existing behavior: today's `do_restart` is used (not a bare `ctx.switch("playing")`) specifically because `ctx` may carry a stale in-progress board if the menu was reached via Pause's "Main Menu" option rather than a fresh launch.
- **Options** → `host:promote(options_screen.new(host))` — direct construction, since `options_screen.lua` already exists.
- **Quit** → `host:quit()`.

Since `game_screen.lua` doesn't exist yet (it's a separate PRD), `MainMenuScreen` takes a `make_game_screen` factory function rather than requiring the module directly — the same dependency-injection pattern already used by `pause_screen.lua` for its `make_main_menu` factory.

`menu.lua`'s existing `main_menu_tree` / `draw_main_menu` / `main_menu_hit_test` are reused unchanged — this PRD only relocates who calls them and wires their callbacks.

## User Stories

1. As a player, I see the same main menu (New Game / Options / Quit) after the refactor, with identical visuals and layout.
2. As a player, pressing Down/Up moves the highlighted item, clamped at the top and bottom of the list, exactly as today.
3. As a player, pressing Enter activates whichever item is currently highlighted.
4. As a player, tapping New Game, Options, or Quit directly activates that item even if a different item was highlighted, exactly as `select_menu_item` does today.
5. As a player, choosing New Game always starts a genuinely fresh board (score 0, empty grid plus starting tiles), even if I navigated here from the Pause screen's "Main Menu" option mid-game.
6. As a player, choosing Options takes me to the Options screen, and choosing Back/Escape there returns me to exactly this main menu.
7. As a player, choosing Quit closes the game.
8. As a developer, I want `MainMenuScreen` constructed with a `make_game_screen` factory rather than a hard `require` of `game_screen.lua`, so this screen can be built, tested, and merged before `GameScreen` exists.
9. As a developer, I want `MainMenuScreen`'s Options action to construct `OptionsScreen` directly (no factory), since that module already exists and is already tested.
10. As a developer, I want `MainMenuScreen` tested in isolation against a stub host (`promote`/`replace`/`quit` spies) and a stub `make_game_screen` factory, following the same pattern as `tests/test_options_screen.lua` and `tests/test_pause_screen.lua`.
11. As a developer reading `tests/test_main_menu.lua` today, I want every behavior it currently exercises against `gamestate.new()` (cursor clamping, Enter dispatch, tap-selection dispatch, ignoring unrelated keys) ported onto direct calls against `MainMenuScreen`, so no coverage is lost in the move.
12. As a developer, I want `menu.lua`'s `main_menu_tree`/`draw_main_menu`/`main_menu_hit_test` left untouched, since `tests/test_menu.lua` already covers their hit-test/layout behavior and this PRD doesn't change that surface.

## Implementation Decisions

- **`game/screens/main_menu_screen.lua`**, interface: `M.new(host, make_game_screen)`.
  - `host`: the `ScreenManager` instance.
  - `make_game_screen`: a 0-arg factory returning a fresh `GameScreen` instance. Injected rather than required directly, since `game_screen.lua` is a separate, not-yet-built PRD.
- **State owned by the screen**: just a `cursor` (0–2), mirroring today's `MenuState._cursor`. No `ctx` table — this screen owns nothing about the board.
- **`enter()`**: resets cursor to 0, matching today's behavior of always landing on New Game when the menu is (re)entered.
- **`keypressed(key)`**: `up`/`down` move and clamp the cursor (0–2); `return` activates whatever the cursor currently points at.
- **A `tap_item(i)`-equivalent for direct activation**: tapping a specific menu item sets the cursor to that item *and* activates it immediately, matching today's `select_menu_item(index)` semantics (used by both `keypressed("return")` and tap dispatch internally, to avoid duplicating the three-way action dispatch).
- **Action dispatch** (shared by Enter and tap):
  - index 0 (New Game) → `host:replace(make_game_screen())`.
  - index 1 (Options) → `host:promote(options_screen.new(host))` (direct `require("screens.options_screen")`).
  - index 2 (Quit) → `host:quit()`.
- **`tap(x, y)`**: wraps `menu.main_menu_hit_test(cursor, callbacks, x, y)`, with `on_new_game`/`on_options`/`on_quit` callbacks each calling the shared activation dispatch for their fixed index — mirrors how `options_screen.lua`'s `tap_row` and `pause_screen.lua`'s `tap` are structured.
- **`draw()`**: delegates to `menu.draw_main_menu(cursor)`.
- **`opaque()`**: not overridden — defaults to `true` in `ScreenManager`. Main Menu is always a stack root (reached only via `replace`), never an overlay.

## Testing Decisions

- Tests assert observable behavior through the public screen interface (`keypressed`, `tap`, `draw`), not internal cursor representation — consistent with `tests/test_options_screen.lua` and `tests/test_pause_screen.lua`.
- **`tests/test_main_menu_screen.lua`**, driven against:
  - a stub host exposing `replace`/`promote`/`quit` spies (same shape as the stub hosts already used for Options/Pause).
  - a stub `make_game_screen` factory returning a sentinel table, so the test can assert `host:replace()` was called with exactly that sentinel.
- Behaviors ported from `tests/test_main_menu.lua` (currently driven through `gamestate.new()`): cursor starts at 0; Down/Up move and clamp the cursor at both ends; Enter on each cursor position fires the right action; tap-selection fires the right action regardless of prior cursor position; unrelated keys (arrow/escape) are no-ops on this screen.
- `tests/test_menu.lua`'s existing `main_menu_hit_test`/`main_menu_tree` coverage is unaffected and untouched.
- `make test-game` must stay green throughout, per this codebase's TDD workflow (one cycle at a time, tracer bullet first).

## Out of Scope

- `game_screen.lua` itself — a separate PRD; this PRD only injects a factory for it.
- Wiring `main.lua` to actually construct `ScreenManager` with `MainMenuScreen` as the initial root, and retiring `gamestate.lua`/`statemachine.lua` — tracked by the parent [Screen Stack Refactor](screen-stack-refactor.md) PRD as a final step once all six screens exist.
- Any change to `menu.lua`'s view-layer functions.

## Further Notes

This PRD is a sibling to [Game Screen](game-screen.md), [Win Screen](win-screen.md), and [Game Over Screen](game-over-screen.md) — all four split out of the parent Screen Stack Refactor PRD so each can be implemented and merged independently via its own `/tdd` session, following the same incremental pattern already used for `screen_manager.lua`, `options_screen.lua`, and `pause_screen.lua`.

Build order isn't strictly fixed, but `MainMenuScreen` only needs a `make_game_screen` factory (never a direct `GameScreen` reference), so it can be implemented before, after, or in parallel with the Game Screen PRD.
