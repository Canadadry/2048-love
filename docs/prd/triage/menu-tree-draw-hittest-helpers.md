---
title: "Dedupe menu.lua's Tree Draw / Hit-Test Boilerplate"
description: "menu.lua repeats the same 'draw every tree.Command' and 'hit-test then invoke callback' pattern four times (main menu, options, win, game over); extract shared helpers."
status: needs-triage
---

## Problem Statement

`menu.lua` builds four independent screen trees (main menu, options, win, game over), each following the exact same shape: a `build_x_tree` builder, an `M.x_tree` wrapper, an `M.draw_x` that loops `for _, cmd in ipairs(tree.Commands) do if cmd.painter then painter.Draw(cmd, cmd.painter) end end`, and an `M.x_hit_test` that runs `local cb = ui.HitTest(tree, x, y); if cb then cb() end`. The draw loop and the hit-test-then-invoke pattern are byte-for-byte identical four times over. As a developer adding a fifth screen to `menu.lua` (or, more likely, a new screen module under the planned screen-stack refactor), today's path is to copy one of these four pairs rather than call something shared.

## Solution

Extract the two repeated patterns into shared helpers, placed according to which existing module can host them without introducing a circular dependency:

- The **hit-test-then-invoke** pattern (`ui.HitTest(tree, x, y)` then call the returned callback if any) moves into `lib/ui/layout/ui.lua`, which already owns `HitTest` and has no dependency on the painter module.
- The **draw-every-command** pattern (`for cmd in tree.Commands ... painter.Draw(cmd, cmd.painter)`) cannot move into `ui.lua` — `painter.lua` already `require`s `lib.ui.layout.ui`, so `ui.lua` requiring `painter.lua` back would create a circular dependency. It moves into `lib/ui/painter/painter.lua` instead, which already depends on `ui.lua` in the needed direction.

`menu.lua`'s four `M.x_tree` / `M.draw_x` / `M.x_hit_test` trios become thin wrappers calling the two new shared helpers instead of repeating the loop and the hit-test-and-invoke pattern inline.

## User Stories

1. As a developer adding a new menu-style screen, I want to call one draw helper and one hit-test helper instead of copy-pasting an existing screen's draw/hit-test pair, so new screens can't drift from the established pattern.
2. As a developer reading `menu.lua`, I want each `M.draw_x` function to read as "draw this tree" rather than re-deriving the same five-line loop each time, so the screen-specific tree-building logic (the actual interesting part) isn't buried in boilerplate.
3. As a developer working on the planned screen-stack refactor, I want these two helpers to already exist in `lib/ui`, so each new `game/screens/*.lua` module can reuse them directly instead of re-discovering the same duplication in a new location.
4. As a player, I want zero observable change — every screen's visuals and tap targets behave identically before and after this refactor.

## Implementation Decisions

- **`lib/ui/layout/ui.lua`**: add a function (e.g. `ui.Tap(tree, x, y)`) that wraps the existing `HitTest(tree, x, y)` and invokes the returned callback if one is found, replacing the `local cb = ui.HitTest(tree, x, y); if cb then cb() end` pattern at all four call sites in `menu.lua`. `HitTest` itself is unchanged and stays exported for any caller that needs the lookup without the invoke.
- **`lib/ui/painter/painter.lua`**: add a function (e.g. `painter.DrawTree(tree)`) that performs the existing `for _, cmd in ipairs(tree.Commands) do if cmd.painter then painter.Draw(cmd, cmd.painter) end end` loop, replacing that loop at all four `M.draw_x` call sites in `menu.lua`. `painter.Draw` (the single-command draw) is unchanged and stays exported.
- `menu.lua`'s four `M.draw_x` functions become: build/reuse the tree, call `painter.DrawTree(tree)` (plus any screen-specific extra drawing, e.g. `draw_win_particles` for the win screen, which stays inline since it isn't tree-based).
- `menu.lua`'s four `M.x_hit_test` functions become: build the tree with callbacks, call `ui.Tap(tree, x, y)`.
- `M.draw_pause` (the one hand-rolled, non-tree-based screen) is explicitly out of scope here — it doesn't go through `tree.Commands` at all, and the existing screen-stack triage PRD already earmarks it for migration onto the `lib/ui` tree system as part of that larger refactor.
- No change to `build_*_tree` functions, callback wiring, or any visual/layout values — this PRD only touches how an already-built tree gets drawn and hit-tested.

## Testing Decisions

- Behavior-level tests only, consistent with this codebase's existing `lib/ui` test style (`lib/ui/layout/ui_test.lua`, `lib/ui/painter/painter_test.lua`) and `tests/test_menu.lua`'s existing approach of asserting on hit-test/draw outcomes rather than internals.
- `lib/ui/layout/ui_test.lua` gets new cases for `ui.Tap`: callback fires when a hit lands on an interactive command, no error/no-op when it misses.
- `lib/ui/painter/painter_test.lua` gets a new case for `painter.DrawTree`: every command with a non-nil `painter` field gets drawn (verifiable the same way existing painter tests verify draw calls, e.g. via a fake/spy graphics backend if one already exists in that test file, otherwise asserting the same outcome that test file currently uses to confirm `painter.Draw` ran).
- `tests/test_menu.lua`'s existing tests for `main_menu_hit_test`, `options_hit_test`, `win_hit_test`, `game_over_hit_test` should continue to pass unchanged — they assert outcomes (which callback fired for a given tap), not which internal loop produced that outcome, so they validate the refactor for free.

## Out of Scope

- `M.draw_pause` / `M.pause_button_bounds` — hand-rolled `love.graphics` calls untouched by this PRD; covered by the existing screen-stack triage PRD instead.
- Any change to `build_main_menu_tree`, `build_options_tree`, `build_win_tree`, `build_game_over_tree`, or the visuals/layout they produce.
- `draw_win_particles` — stays as menu.lua-local logic called alongside (not replaced by) `painter.DrawTree`, since particles aren't part of the `lib/ui` tree.

## Further Notes

This was identified during a `/guideline`-driven technical-debt survey, not a user-reported bug. The split between `ui.lua` (hit-test+invoke) and `painter.lua` (draw-all-commands) is dictated by the existing `painter.lua -> ui.lua` require direction discovered while investigating — putting both helpers in `ui.lua` as originally suggested would create a circular `require`.
