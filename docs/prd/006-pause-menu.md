---
title: "Pause Menu"
description: "Pressing Escape quits the game immediately with no recovery, and there is no way to pause mid-session."
status: done
---

## Problem Statement

There is no way to pause the game mid-session. Pressing Escape quits the application immediately with no confirmation and no chance to resume. A player who needs to step away loses their current board and score.

## Solution

Repurpose the Escape key as a pause toggle. Pressing Escape during active play opens a pause overlay over the dimmed board. The overlay presents three actions: Resume, New Game, and Quit. The game remains frozen while the menu is visible. Pressing Escape again or selecting Resume returns to the game exactly where it was left.

## User Stories

1. As a player, I want to press Escape to pause the game, so that I can step away without losing my current board and score.
2. As a player, I want to press Escape again to resume instantly, so that I do not have to navigate to a button to get back to playing.
3. As a player, I want the board to remain visible but dimmed behind the pause overlay, so that I can see my current position while deciding what to do.
4. As a player, I want a Resume option clearly highlighted by default, so that pressing Enter immediately unpauses without additional navigation.
5. As a player, I want to navigate pause menu options with the Up and Down arrow keys, so that I can use the keyboard throughout.
6. As a player, I want to activate a pause menu option with Enter, so that the keyboard navigation feels consistent with the win screen.
7. As a player, I want to click a pause menu button with the mouse, so that I can use the menu without a keyboard.
8. As a player, I want to tap a pause menu button on a touch screen, so that the menu is usable on mobile.
9. As a player, I want a New Game option in the pause menu, so that I can restart without going through the game-over or win overlay.
10. As a player, I want New Game to take effect immediately without a confirmation dialog, so that restarting is quick.
11. As a player, I want a Quit option in the pause menu, so that I have a deliberate path to exit the application rather than Escape quitting without warning.
12. As a player, I want the pause menu to be unavailable while the win or game-over overlay is showing, so that overlays do not stack confusingly.
13. As a player, I want tile slide animations to finish before the pause menu appears if I press Escape mid-animation, so that tiles do not freeze in an awkward mid-flight position.
14. As a player, I want any moves I queued before pausing to be discarded when the menu opens, so that I do not get surprise tile movements the moment I resume.
15. As a player, I want the pause cursor to always start on Resume when the menu opens, so that the default action is always the safe one.

## Implementation Decisions

- **`gamestate` module** gains three new fields: `_paused` (boolean, game is currently paused), `_pause_pending` (boolean, Escape was pressed during an animation — menu opens as soon as the animation settles), and `_pause_cursor` (integer 0–2, separate from the existing win-screen `_cursor` field to avoid semantic collision). New getters `paused()` and `pause_cursor()` are exposed. The `update()` method checks `_pause_pending` each frame after animations drain and, if set, clears the move queue, resets `_pause_cursor` to 0, and sets `_paused = true`. While `_paused` is true, `update()` does not dequeue or apply moves.

- **`gamestate` keypressed logic**:
  - If the win or game-over overlay is active, Escape is ignored (existing overlay handlers take precedence).
  - If `_paused` is true: Up/Down move `_pause_cursor` (clamped 0–2), Enter activates the selected item, Escape resumes (equivalent to selecting Resume). All other keys are ignored.
  - If not paused and not frozen: Escape during an active animation sets `_pause_pending`; Escape when idle enters pause immediately (clears queue, resets cursor, sets `_paused = true`).

- **`gamestate` public actions** added: `resume()` clears `_paused`; the existing `restart()` is reused for New Game; Quit is handled in `main` by calling `love.event.quit()` when the pause menu selection is Quit.

- **`renderer` module** gains a `pause_button_bounds()` function that returns three labeled button rects (Resume, New Game, Quit), computed from the same `board_metrics()` helper used by win/game-over buttons. `draw()` accepts two new arguments — `paused` and `pause_cursor` — and, when `paused` is true, draws the same semi-transparent overlay pattern used for win/game-over, followed by the three buttons with the cursor-highlighted item in orange.

- **`main` module**: the `if key == "escape" then love.event.quit() end` guard is removed; Escape is now handled entirely inside `gamestate.keypressed()`. `love.draw()` passes `state:paused()` and `state:pause_cursor()` to `renderer.draw()`. `handle_tap()` is extended to hit-test pause buttons when `state:paused()` is true and call `state:resume()`, `state:restart()`, or `love.event.quit()` accordingly.

## Testing Decisions

Good tests exercise the externally visible contract of a module — the state it exposes through its getters — not its internal field layout. Use `gamestate.new_from()` to seed deterministic board states, drive the module through `keypressed()` and `update()` calls, and assert on `paused()`, `pause_cursor()`, `score()`, `game_over()`, `win()`, and `is_animating()`. Prior art: `tests/test_gamestate.lua` uses this exact pattern with a plain `pcall`-based harness.

**`gamestate` tests** (high value, isolated logic):
- Escape while idle enters pause (`paused()` becomes true).
- Escape while paused resumes (`paused()` becomes false).
- Escape mid-animation sets pending; pause opens only after `update()` drains the animation.
- Queue is discarded on pause (queue a move, pause, resume, verify no tile slide occurs without new input).
- `pause_cursor` starts at 0 when menu opens; Up/Down move it; it clamps at 0 and 2.
- Enter with cursor=0 (Resume) clears `_paused`.
- Enter with cursor=1 (New Game) resets score to 0 and `paused()` becomes false.
- Escape is ignored while win overlay is showing.
- Escape is ignored while game-over overlay is showing.

**`renderer` tests** — `pause_button_bounds()` returns three tables each with `x`, `y`, `w`, `h` fields whose values are finite positive numbers.

**`main` integration tests** — not applicable; `main` is a Love2D callback shim with no testable API surface of its own.

## Out of Scope

- Confirmation dialog before New Game.
- A visible on-screen pause button (tap-to-pause without keyboard).
- Settings or options sub-menu.
- Best score display inside the pause overlay.
- Sound muting on pause.

## Further Notes

The `_pause_cursor` field (0–2) is intentionally separate from `_cursor` (0–1, used for the win screen). Both fields can coexist on the state object without conflict because pause and win states are mutually exclusive; the renderer uses whichever is appropriate based on the `paused` and `win` flags passed in.

`_frozen` is not reused for pause because it carries win/game-over semantics. Pause uses `_paused` so the two conditions remain independently readable.
