---
title: "Real Layout System for Menus"
description: "menu.lua hand-computes pixel positions for every screen (main menu, options, pause, win, game over) by re-deriving board_metrics() and manually offsetting x/y for each button and label, instead of using a real layout system."
status: needs-triage
---

# Real Layout System for Menus

## Problem Statement

`menu.lua` and `renderer/board.lua`'s `board_metrics()` compute every screen's button and label positions by hand: each `draw_*`/`*_button_bounds` function re-derives `board_px`/`tile_px`/`board_x`/`board_y` and manually offsets pixel coordinates (`top_y + (btn_h + gap) * i`, centered text via `getWidth()/2`, etc.). This is repeated with slight variations across the main menu, options screen, pause menu, win screen, and game-over screen, and `main.lua`'s tap handling re-derives the same bounds separately to hit-test clicks. There's no real layout system — no concept of stacks, padding rules, or anchors that the screens share.

## Solution

Not yet decided — this PRD is registered as a placeholder. The actual design (what a "layout system" means here: a stack/flex-like helper, a declarative widget tree, etc.) needs a dedicated grilling session before implementation starts.

## User Stories

TBD — to be filled in during the grilling session.

## Implementation Decisions

TBD — to be filled in during the grilling session. Open questions to resolve then include at least:

- Whether this is a generic reusable layout primitive (e.g. vertical/horizontal stack with padding/gap) or a thin shared helper just for button lists.
- Whether `menu.lua`'s five `draw_*` functions and their matching `*_button_bounds` functions get rebuilt on top of it, or only new screens use it going forward.
- How hit-testing in `main.lua`'s `handle_tap()` consumes the same layout output instead of recomputing bounds independently.
- Whether this touches `renderer/board.lua`'s `board_metrics()` or stays purely in `menu.lua`.

## Testing Decisions

TBD — to be filled in during the grilling session.

## Out of Scope

TBD — to be filled in during the grilling session.

## Further Notes

This PRD was registered without a grilling session at the user's explicit request — implementation must not start until `/grill-me` has been run against it and the sections above are filled in.
