---
title: "Touch Usability Fixes (Options Screen + Pause Button)"
description: "On touch devices, the Options screen cannot be operated by tapping at all, and the pause button sits in the extreme top-left corner where it's hard to reach/tap reliably."
status: needs-triage
---

# Touch Usability Fixes (Options Screen + Pause Button)

## Problem Statement

Two touch-specific usability bugs, reported by the user, not yet designed:

1. **Options screen is unusable via touch.** `main.lua`'s `handle_tap(x, y)` has dedicated branches for `state:in_menu()`, `state:paused()`, `state:win()`, and `state:game_over()`, but no branch at all for `state:in_options()`. Tapping anywhere on the Options screen (Win Tile / Theme / Animations / Effects rows) does nothing — there's no touch equivalent of the Up/Down (focus row) or Left/Right (cycle value) keyboard interactions, and no way to tap "back" to the main menu either.
2. **Pause button is hard to reach/tap.** `menu.lua`'s `pause_icon_bounds()` fixes the pause icon at `{ x = 8, y = 8, w = sz, h = sz }` — pinned to the extreme top-left corner of the window with only an 8px margin. The user reports it's too far up-left to be clicked reliably on a touch device.

## Solution

Not yet decided — this PRD is registered as a placeholder. The actual fix (touch gesture mapping for the Options rows, repositioning/resizing the pause button, or a broader touch-target review) needs a dedicated grilling session before implementation starts.

## User Stories

TBD — to be filled in during the grilling session.

## Implementation Decisions

TBD — to be filled in during the grilling session. Open questions to resolve then include at least:

- For the Options screen: should tapping a row focus it (mirroring Up/Down), and if so how does Left/Right's value-cycling map to touch (tap the row again to cycle? dedicated left/right tap zones per row? swipe?). Should tapping outside all rows act as "back" (mirroring Escape)?
- For the pause button: is the fix a position change (e.g. more inset margin, different corner), a size change (bigger touch target), or both? Does this need to account for device safe areas (notches, rounded corners) at all, or is a fixed-but-larger inset sufficient?
- Whether this PRD should also do a broader audit of touch targets across all screens (existing `pause_icon_bounds` test already asserts "at least 44x44 for touch targets" — should that same minimum be asserted/enforced elsewhere?), or stay scoped to just these two reported bugs.

## Testing Decisions

TBD — to be filled in during the grilling session.

## Out of Scope

TBD — to be filled in during the grilling session.

## Further Notes

This PRD was registered without a grilling session at the user's explicit request — implementation must not start until `/grill-me` has been run against it and the sections above are filled in.
