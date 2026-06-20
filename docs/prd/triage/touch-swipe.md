---
title: "Touch Swipe Input"
description: "The game is keyboard-only, making it unplayable on phones and tablets where no hardware keyboard is available."
status: needs-triage
---

# Touch Swipe Input

## Problem Statement

The game is keyboard-only. On a phone or tablet (the primary target platform via Love2D Studio on iOS), there is no hardware keyboard, so the player has no way to move tiles or restart after a game over.

## Solution

Swipe gestures on the screen trigger tile moves in the swiped direction. A visible "New Game" button appears on the game-over screen so the player can restart without a keyboard. Arrow-key input continues to work alongside touch for desktop testing.

## User Stories

1. As a mobile player, I want to swipe left/right/up/down to move tiles, so that I can play without a keyboard.
2. As a mobile player, I want a short swipe to be ignored and only a deliberate swipe to trigger a move, so that accidental touches do not disrupt the game.
3. As a mobile player, I want a diagonal swipe to trigger the move along whichever axis I swiped more, so that imprecise swipes still work.
4. As a mobile player, I want swipes I make during an animation to be remembered and applied once the animation finishes, so that I can swipe at my own pace without losing inputs.
5. As a mobile player, I want queued swipes applied one at a time, so that a burst of swipes plays out as a clear sequence of moves rather than skipping steps.
6. As a mobile player, I want to see a "New Game" button on the game-over screen, so that I can restart without a keyboard.
7. As a mobile player, I want to tap the "New Game" button to start a fresh game, so that I can keep playing after losing.
8. As a desktop tester, I want arrow keys to keep working alongside swipe input, so that I can test the game without a touchscreen.

## Implementation Decisions

- **`swipe.lua`** (new module) — pure gesture detector with no Love2D dependency. Tracks one active touch per touch id. `new(threshold_fraction)` returns a detector; `threshold_fraction` defaults to `0.10` (10% of the shortest screen dimension, computed from `love.graphics.getDimensions()` at detection time so it adapts to resize). `:touchpressed(id, x, y)` records the start position. `:touchreleased(id, x, y)` computes `dx = x - start_x`, `dy = y - start_y`; if `math.max(math.abs(dx), math.abs(dy))` is below the threshold, returns `nil`; otherwise returns `"left"`, `"right"`, `"up"`, or `"down"` based on whichever of `|dx|`/`|dy|` is larger. `:touchmoved` is a no-op (direction is resolved on release only).

- **`gamestate.lua`** (modified) — gains `_queue` (ordered list of direction strings). `State:queue_move(dir)` appends to the queue. `State:update(dt)` is extended: after all animation tiles are purged, if `_queue` is non-empty, it pops the first entry and calls the existing move logic (same path as `keypressed`). `State:restart()` resets to a fresh board (equivalent to `M.new()`). The swipe queue is unbounded — no cap.

- **`renderer.lua`** (modified) — when `game_over` is true, draws a "New Game" button. `renderer.restart_button_bounds()` returns `{x, y, w, h}` in screen coordinates so `main.lua` can hit-test taps. Button position and size are derived from the existing layout (centered below the grid, consistent with the score display style).

- **`main.lua`** (modified) — adds three Love2D callbacks:
  - `love.touchpressed(id, x, y, dx, dy, pressure)` — forwards `(id, x, y)` to the swipe detector; if `state:game_over()`, also checks whether `(x, y)` falls within `renderer.restart_button_bounds()` and calls `state:restart()` if so.
  - `love.touchmoved(id, x, y, ...)` — forwarded to swipe detector (no-op there, kept for API completeness).
  - `love.touchreleased(id, x, y, ...)` — forwards to swipe detector; if a direction is returned and the game is not over/frozen, calls `state:queue_move(dir)`.

## Testing Decisions

- Tests live in `tests/test_swipe.lua`, following the same `test(name, fn)` / `eq(a, b)` harness pattern used in `test_grid.lua`, `test_gamestate.lua`, etc.
- Only `swipe.lua` is unit-tested. The queue draining in `gamestate.lua` and the button hit-test in `main.lua` are integration concerns exercised manually.
- Good tests check external behavior only — given a sequence of `touchpressed` / `touchreleased` calls with known coordinates, assert the returned direction. Tests must not reach into internal state of the detector.
- Cases to cover: clean horizontal swipe → `"right"`/`"left"`; clean vertical swipe → `"up"`/`"down"`; diagonal swipe where `|dx| > |dy|` → horizontal direction; diagonal swipe where `|dy| > |dx|` → vertical direction; swipe below threshold → `nil`; two independent touches resolved in sequence.

## Out of Scope

- Restart button on the win screen (win screen remains frozen, same as today).
- Swipe queue cap / maximum depth.
- Visual feedback during a swipe (e.g. highlight or arrow overlay).
- Multi-touch simultaneous moves.

## Further Notes

Love2D Studio on iOS uses the standard Love2D touch API (`love.touchpressed`, `love.touchmoved`, `love.touchreleased`), so no platform-specific shim is needed. The threshold fraction approach means the gesture feels consistent whether the device is an iPhone SE or a 12.9" iPad Pro.
