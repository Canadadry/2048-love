---
title: "Mouse Tap/Swipe Disambiguation Parity"
description: "A mouse click that turns into a drag can still fire the button under the cursor, because main.lua fires handle_tap unconditionally on mouse-down instead of deferring to release like touch does."
status: needs-triage
---

# Mouse Tap/Swipe Disambiguation Parity

## Problem Statement

On touch devices, `love.touchreleased` only calls `handle_tap(x, y)` when the gesture turns out not to have been a swipe (`swiper:touchreleased` returns `nil`). On desktop, `love.mousepressed` calls `handle_tap(x, y)` immediately on mouse-down, before the gesture is known to be a tap or a drag at all.

This means a mouse user pressing down on a button (pause icon, pause-menu buttons, win/game-over buttons, main-menu buttons) and then dragging — intending a board swipe, or just an imprecise click — still triggers that button's action on press, in addition to whatever swipe direction the drag resolves to on release. Touch users don't experience this: dragging away from a button never fires it, because the tap is only resolved at release and only when the gesture wasn't a swipe. Desktop and touch interaction therefore behave differently for the same gesture, and desktop users can trigger button actions (including quitting, restarting, or leaving the game) they didn't intend to trigger.

## Solution

Make `love.mousepressed` / `love.mousereleased` resolve taps the same way `love.touchpressed` / `love.touchreleased` already do: a mouse-down only registers the gesture start, and `handle_tap` only fires on mouse-up, and only when the swipe detector determined the gesture was not a swipe. No change to `swipe.lua` — it already treats the `"mouse"` id like any other touch id; the asymmetry is entirely in how `main.lua` wires the mouse callbacks.

## User Stories

1. As a desktop player, I want clicking a button (pause icon, pause-menu buttons, win/game-over buttons, main-menu buttons) to fire that button's action, so that mouse clicks work as expected.
2. As a desktop player, I want pressing down on a button and then dragging away before releasing to NOT fire that button's action, so that an imprecise click or an attempted board swipe doesn't accidentally trigger something I didn't mean to click.
3. As a desktop player, I want pressing down anywhere on the board and dragging far enough to register a swipe to move tiles in that direction, exactly as it does today, so that the fix doesn't regress existing swipe-to-move behavior.
4. As a desktop player, I want pressing down on a button and releasing in place (no drag) to fire the button's action, so that a normal click still works after the fix.
5. As a desktop player, I want this fix to only change *when* a tap is resolved, not *what* a tap does, so that all existing `handle_tap` behavior (menu routing, pause/win/game-over buttons) is otherwise unaffected.
6. As a mobile/touch player, I want touch behavior to remain completely unchanged, so that this desktop-only fix introduces no touch regressions.
7. As a developer maintaining `main.lua`, I want the mouse and touch event-handling code paths to be structurally symmetric, so that future changes to tap/swipe resolution only need to be made once and can't drift apart again.

## Implementation Decisions

- Only `game/main.lua` changes. `swipe.lua`, `menu.lua`, and `gamestate.lua` are untouched — `handle_tap` itself is unchanged; only the call sites in the mouse handlers move.
- `love.mousepressed`: keep `swiper:touchpressed("mouse", x, y)`, drop the immediate `handle_tap(x, y)` call.
- `love.mousereleased`: after computing `dir = swiper:touchreleased("mouse", x, y)`, branch exactly like `love.touchreleased` already does — if `dir` is present, queue the move (when not game-over/win, as today); otherwise call `handle_tap(x, y)`.
- Because this makes `love.mousereleased` and `love.touchreleased` resolve to the same dir-or-tap branching logic, extract that shared branch into one private helper (e.g. a `resolve_release(dir, x, y)` called from both handlers) instead of duplicating it, so the two input paths can't drift apart again.
- `love.mousemoved` / `love.touchmoved` are unaffected — they already only queue swipe moves, never call `handle_tap`.

## Testing Decisions

- Tests added to `tests/test_main.lua`, reusing its existing `dofile("main.lua")` + `love.load()` pattern (state starts `in_menu()` by default, so the main menu's "Quit" button is a convenient, already-wired target since it ends in an observable, stubbable global: `love.event.quit`).
- Locate the "Quit" button's screen coordinates the same way `tests/test_menu.lua`'s `button_centers()` helper does, via `menu.main_menu_tree(0, {})`.
- Stub `love.event.quit` to record call count instead of letting it run, then assert:
  1. A mouse-down alone over "Quit" (no release) must NOT call `love.event.quit` — this is the regression this PRD fixes, and fails against the current code.
  2. A mouse-down followed by a mouse-up at the same coordinates over "Quit" (no drag) DOES call `love.event.quit` exactly once — confirms ordinary clicks still work.
  3. A mouse-down over "Quit" followed by a mouse-up far enough away to cross the swipe threshold must NOT call `love.event.quit` — confirms a drag-away cancels the tap, mirroring touch.
- `tests/test_swipe.lua` and `tests/test_menu.lua` are unaffected and must continue to pass unmodified, since neither `swipe.lua` nor `menu.lua` changes.
- Good tests here exercise only `love.mousepressed` / `love.mousereleased` (the public LÖVE callback surface) and assert via the externally observable `love.event.quit` stub — they must not reach into `main.lua`'s private `state` or `swiper` locals.

## Out of Scope

- The menu-cursor desync bug found in the same review: `handle_tap`'s `on_new_game` / `on_options` / `on_quit` callbacks replay relative keypresses (`"down"`, `"down"`, `"return"`) assuming the menu cursor starts at 0, so a tap can fire the wrong action (or quit) if the keyboard cursor was moved beforehand. This is a separate, more severe bug tracked independently and not fixed by this PRD.
- Changing the swipe threshold value.
- Any change to `love.touchpressed` / `love.touchmoved` / `love.touchreleased` — they're already correct and serve as the reference behavior this PRD copies.
- Visual feedback for press/drag state (e.g. button highlight while held).

## Further Notes

This PRD was written from a code-review finding, not a user bug report: reviewing `handle_tap` surfaced that mouse and touch disambiguate taps from swipes differently. The companion bug (menu-cursor desync, listed above as Out of Scope) was found in the same review and is intentionally left for a separate PRD/fix.
