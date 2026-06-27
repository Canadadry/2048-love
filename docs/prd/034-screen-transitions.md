---
title: "Screen Transitions"
description: "Replace the screen stack with a single-slot screen manager that supports animated transitions between screens via composable transition functions."
status: done
---

# Screen Transitions

## Problem Statement

The screen stack (`promote`/`dismiss`) was introduced to support overlay screens (Pause, Win, Game Over, Options) that sit visually on top of an active screen. This mechanism is now more complex than the use case requires: screens never truly layer for long — each overlay only appears briefly then navigates away. Meanwhile, there is no visual feedback when navigating between screens; every transition is an instant hard cut, with no animation to communicate direction or context.

## Solution

Collapse the screen stack to a single active screen slot. The only navigation operation is `replace`, which can optionally animate the transition using a caller-supplied function. During a transition, both the outgoing and incoming screens are rendered to their own canvas each frame; a transition function receives those two canvases plus a 0→1 progress value and composites them however it likes. A built-in push transition (new screen slides in, old screen slides out — like a tile pushing another on the board) provides the default game feel. Overlay screens (Pause, Win, Game Over, Options) accept the screen they came from as a constructor parameter and navigate back to it via `replace` instead of `dismiss`.

## User Stories

1. As a player, when I navigate from one screen to another, I see a smooth push animation where the new screen slides in from one side and the old screen exits the other side, like a tile being pushed across the board.
2. As a player, the transition feels consistent and snappy — it does not linger long enough to interrupt my interaction.
3. As a player, I cannot accidentally trigger an action (key press, tap, swipe) while a screen transition is in progress — inputs are silently swallowed until the transition completes.
4. As a player, both the outgoing and incoming screen continue animating during the transition (tile slide animations, particles) — the screens are live, not frozen snapshots.
5. As a player, navigating from the main menu to Options, and back, feels as smooth as any other screen change.
6. As a player, opening Pause, selecting Resume, and returning to the game feels like a screen push in reverse — no abrupt cut.
7. As a player, choosing Main Menu from Pause, Win, or Game Over takes me to the main menu with a smooth transition.
8. As a player, restarting from Win or Game Over returns me to my game screen with a smooth transition.
9. As a player, all existing screen content (board state, score, menu cursor position) is exactly as I left it when I return to a screen I came from.
10. As a player, turning off Animations in Options does not affect screen transitions — screen transitions always animate.
11. As a developer, I can provide any transition style — fade, zoom, wipe — by passing a different `fn(canvas_out, canvas_in, progress)` to `replace`, without modifying `screen_manager`.
12. As a developer, I can pass `nil` as the transition function to get an instant cut with no animation.
13. As a developer, `screen_manager` holds exactly one active screen at a time outside of transitions; the stack, `promote`, and `dismiss` operations are gone.
14. As a developer, the transition duration is specified per `replace` call, so different navigation paths can have different timings.
15. As a developer, calling `replace` while a transition is already in progress is rejected (errors) so transitions cannot nest or interrupt each other.
16. As a developer, `transitions.lua` is a standalone module that exports named transition factories; adding a new visual style requires only adding a new function there.

## Implementation Decisions

- **`lib/screen_manager.lua`** is simplified from a stack to a single `_current` slot plus an optional `_transition` state table.
  - `SM:replace(screen, fn, duration)` is the only navigation method. `fn` and `duration` are optional; if both are nil the swap is instant (exit old, enter new synchronously, same frame).
  - When `fn` is provided: two `love.graphics.newCanvas()` are created at the current window dimensions; the outgoing screen's `exit()` is deferred until the transition ends; input is blocked (`_transitioning = true`); each `update(dt)` advances `elapsed` and calls `update(dt)` on both screens; each `draw()` renders both screens to their respective canvases then calls `fn(canvas_out, canvas_in, elapsed/duration)`; when `elapsed >= duration` the transition ends — `exit()` is called on the outgoing screen, `_transitioning` is cleared, and the incoming screen becomes `_current`.
  - `SM:update(dt)`: during transition, updates both outgoing and incoming screens; outside transition, updates `_current` only.
  - `SM:draw()`: during transition, renders outgoing to `canvas_out`, incoming to `canvas_in`, calls the transition fn; outside transition, calls `_current:draw()` directly.
  - Input dispatch (`keypressed`, `tap`, `resize`, mouse/touch): during transition, all input is silently swallowed; outside transition, dispatches to `_current`.
  - `promote` and `dismiss` are removed. `lib/stack.lua` is no longer required by `screen_manager` (keep the file if no other module uses it, otherwise delete).
  - The re-entrancy guard is preserved: calling `replace` from within an active `replace` (e.g. from a screen's `enter()`) raises an error.
  - Canvas pair is recreated on each `replace` call that includes a transition; it is not cached across calls.

- **`lib/transitions.lua`** (new module) exports transition function factories. Each factory returns a `fn(canvas_out, canvas_in, progress)` closure that draws the composite frame using `love.graphics.draw`.
  - `transitions.push(dir)` — `dir` is `"left"`, `"right"`, `"up"`, or `"down"`. At `progress = 0` the outgoing canvas fills the screen and the incoming canvas is fully offscreen. At `progress = 1` the incoming canvas fills the screen and the outgoing canvas is fully offscreen. Both canvases move at the same rate (the incoming canvas enters from the opposite edge), producing the tile-push feel.
  - The module is the single place where new transition styles are added (fade, zoom, etc.) — no changes to `screen_manager` are needed for new styles.

- **Screen changes** — all `promote`/`dismiss` calls are replaced with `replace`:
  - `game_screen.lua`: win → `host:replace(host:spawn("win", self), fn, dur)`; game over → `host:replace(host:spawn("game_over", self), fn, dur)`; escape/pause → `host:replace(host:spawn("pause", self), fn, dur)`. The `_pause_pending` deferred-pause logic is preserved as-is; the only change is swapping `promote` for `replace` at the call site.
  - `pause_screen.lua` receives `game` (the game screen instance) as a constructor parameter. Resume → `host:replace(self.game, fn, dur)`; New Game → `self.game:restart(); host:replace(self.game, fn, dur)`; Main Menu → `host:replace(host:spawn("main_menu"), fn, dur)`; Quit → `host:quit()`. Escape key mirrors Resume.
  - `win_screen.lua` receives `game` as a constructor parameter. Continue → `self.game:mark_win_seen(); host:replace(self.game, fn, dur)`; Restart → `self.game:restart(); host:replace(self.game, fn, dur)`; Main Menu → `host:replace(host:spawn("main_menu"), fn, dur)`.
  - `game_over_screen.lua` receives `game` as a constructor parameter. New Game → `self.game:restart(); host:replace(self.game, fn, dur)`; Main Menu → `host:replace(host:spawn("main_menu"), fn, dur)`.
  - `main_menu_screen.lua`: Options → `host:replace(host:spawn("options"), fn, dur)` (was `promote`).
  - `options_screen.lua`: Back/Escape → `host:replace(host:spawn("main_menu"), fn, dur)` (was `dismiss`).
  - The `previous` parameter on `host:spawn(name, previous)` that currently passes a game screen reference is reused for `pause`, `win`, and `game_over` — the API already supports it.

- **`game_screen.lua` `resume()` hook**: currently called by `dismiss` to re-sync the swipe threshold. With `replace`, `enter()` is called instead of `resume()` when navigating back to the game screen. The swipe threshold sync should move to `enter()` (or be removed if the game screen already handles resize separately — it does, via `resize(w, h)`).

- **Transition direction convention**: the specific `dir` argument passed to `transitions.push` at each call site is a product decision left to implementation — not locked in this PRD. A consistent convention (e.g. "forward" navigations push left, "back" navigations push right) should be chosen and applied uniformly at implementation time.

- **Canvas dimensions**: canvases are created at `love.graphics.getDimensions()` at the moment `replace` is called. A window resize mid-transition is not handled — transitions are short enough that this edge case is acceptable.

## Testing Decisions

- Tests assert observable behavior, not internal state — consistent with the existing style in `game/lib/screen_manager_test.lua` and `game/screens/*_test.lua`.
- **`lib/screen_manager_test.lua`** is updated: remove all `promote`/`dismiss` test cycles; add cycles for transition lifecycle — that both screens receive `update(dt)` during transition; that input is blocked during transition and resumes after; that `replace` while `_transitioning` raises an error; that instant `replace` (nil fn) still calls `exit` on the old screen and `enter` on the new screen in the same call; that `top()` / `_current` reflects the incoming screen only after the transition completes.
  - Transition rendering (the canvas draw calls) is not unit-tested — it requires a real Love2D graphics context. Behavior is verified by running the game.
- **`lib/transitions.lua`**: the push math (position of each canvas at a given progress value) can be tested in isolation if the module exposes the position calculation as a pure function, independent of the Love2D draw call. If it does not, skip unit tests for this module — the visual output is the spec.
- **Per-screen tests** (`screens/*_test.lua`): stub hosts are updated to expose `replace` (replacing `promote`/`dismiss` spies). Each test that previously asserted `host.promote_calls` or `host.dismiss_count` is rewritten to assert `host.replace_calls` with the correct target screen. No new behavior is tested — this is a mechanical substitution at the call-site level.
- Prior art: `game/lib/screen_manager_test.lua`, `game/screens/game_screen_test.lua`, `game/screens/pause_screen_test.lua`.

## Out of Scope

- Adding new transition styles beyond the push — `transitions.lua` is the extension point; new styles are future work.
- Changing any screen's visual content, layout, or menu items — this PRD only changes how screens are wired together.
- The `lib/stack.lua` module itself — it may be deleted if unused after this change, or kept if referenced elsewhere; the decision is left to the implementer.
- `ANIMATIONS_ENABLED` — screen transitions are always animated regardless of this setting.
- Handling window resize mid-transition.

## Further Notes

- The push transition is thematically motivated: it mirrors the tile-push mechanic that defines the game, giving screen navigation the same physical feel as gameplay.
- The transition function signature `fn(canvas_out, canvas_in, progress)` deliberately keeps `screen_manager` unaware of any specific visual style — it only owns the timer and the canvas pair. This is the deep module boundary: timing and canvas management in `screen_manager`, compositing logic entirely in the transition function.
- Overlay screens (Pause, Win, Game Over) no longer see the game board behind them — they are full-screen replacements. This is an intentional UX simplification: the game board visible behind the dimmed overlay was a side-effect of the stack architecture, not a deliberate design goal.
