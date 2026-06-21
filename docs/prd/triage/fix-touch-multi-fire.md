---
title: "Fix Touch Multi-Fire"
description: "A single swipe gesture on a real touch device queues multiple tile moves instead of one."
status: needs-triage
---

# Fix Touch Multi-Fire

## Problem Statement

On a real touch device (iOS via Love2D Studio), swiping once to slide tiles causes 2–4 moves to execute instead of 1. The board advances several steps per gesture, making the game feel uncontrollable and unplayable on mobile.

## Solution

Cap each touch gesture at exactly one move. Once a swipe direction has been fired during a drag (`touchmoved`), further movement within that same touch contact is ignored. The move fires as early as possible (when the drag crosses the threshold mid-gesture) but fires at most once per touch-down/touch-up cycle.

## User Stories

1. As a mobile player, I want a single finger swipe to move tiles exactly once, so that the game advances one step per gesture as intended.
2. As a mobile player, I want a quick flick (finger lifts before threshold is crossed mid-drag) to still register a move, so that fast swipes are not lost.
3. As a mobile player, I want a slow deliberate drag to register a move as soon as my finger crosses the threshold, so that I do not have to wait until I lift my finger.
4. As a mobile player, I want subsequent drag movement after a move has already fired to be silently ignored, so that I cannot accidentally queue extra moves by following through on my swipe.
5. As a desktop tester, I want mouse-drag behaviour to follow the same single-fire rule, so that desktop testing reflects mobile behaviour.
6. As a desktop tester, I want arrow-key input to continue working unchanged, so that keyboard testing is unaffected by the touch fix.

## Implementation Decisions

- **`swipe.lua`** is the only module modified. The gesture detector tracks a `fired` flag per active touch. The fix has two parts:

  1. **Early return in `touchmoved`**: at the top of the function, if `s.fired` is already `true`, return `nil` immediately. This prevents re-firing after the first threshold crossing.

  2. **Remove the origin reset**: the line that updates `s.x = x; s.y = y` after firing served only to enable continuous re-firing. With the early return in place, it is dead code; removing it makes the intent clear.

  The `touchreleased` fallback path (fires when `touchmoved` never crossed the threshold) is unchanged: `fired` is still `false` at that point, so it computes direction from the original start position as before.

- No changes to `main.lua`, `gamestate.lua`, or any other module. The fix is entirely contained within `swipe.lua`.

## Testing Decisions

- Tests live in `tests/test_swipe.lua`, using the existing `test(name, fn)` / `eq(a, b)` harness (same pattern as `test_grid.lua`, `test_gamestate.lua`).
- Good tests drive only the public API (`touchpressed`, `touchmoved`, `touchreleased`) and assert on return values. They must not reach into internal state (`_starts`, `fired`, etc.).
- **One existing test must be updated**: `"touchmoved fires again from new origin after first fire (continuous drag)"` currently asserts the old multi-fire behavior. It should be replaced by a test asserting that a second `touchmoved` call after the first fire returns `nil`.
- **New test to add**: a sequence where `touchmoved` fires, then several more `touchmoved` calls follow, then `touchreleased` — assert that only one direction was ever returned across the whole sequence.
- All other existing tests remain valid and must continue to pass.

## Out of Scope

- Spurious tap after a consumed swipe: `handle_tap` is currently called on `touchreleased` whenever `swiper:touchreleased` returns `nil`, which includes the gesture-consumed case. This is a separate bug not reported by the user and is not addressed here.
- Adjusting the swipe threshold value.
- Capping the move queue depth in `gamestate.lua`.
- Visual swipe feedback (arrow overlay, highlight).

## Further Notes

The original `touch-swipe.md` PRD specified `touchmoved` as a no-op (direction resolved on release only). The current implementation diverges from that: it fires early on `touchmoved` to improve responsiveness. This PRD preserves the early-fire behavior (better feel for slow drags) while adding the single-fire guard. The result is: fire as early as possible, but never more than once per gesture.
