---
title: "Real Layout System for the Main Menu"
description: "menu.lua hand-computes pixel positions for the main menu by re-deriving board_metrics() and manually offsetting x/y for the title and three buttons, instead of using the vendored lib/ui layout system."
status: ready
---

# Real Layout System for the Main Menu

## Problem Statement

`menu.lua`'s `draw_main_menu()` and `main_menu_button_bounds()` each independently re-derive `board_px`/`tile_px`/`board_x`/`board_y` via a private `board_metrics()` and manually offset pixel coordinates (`top_y + (btn_h + gap) * i`, centered text via `getWidth()/2`, etc.) to lay out the title and three buttons. `main.lua`'s `handle_tap()` then re-derives the same bounds a third time, independently, just to hit-test taps against the same three buttons. There's no shared layout primitive between drawing and hit-testing — both sides hand-compute the same geometry from scratch and must be kept in sync by hand.

The same pattern exists in the options, pause, win, and game-over screens, but this PRD scopes down to the main menu only — see Out of Scope.

## Solution

Rebuild the main menu's title+buttons on the already-vendored `lib/ui` layout/painter library (`game/lib/ui/`) instead of hand-rolled pixel math. The main menu's root frame becomes a plain full-window-centered column (mirroring `game/lib/ui/example/main.lua`'s structure almost exactly), so there's exactly one declarative tree shape that both drawing and hit-testing build from — no more independently-maintained bounds math.

Hit-testing is unified by extending `lib/ui` itself with a small, generic, reusable mechanism: nodes can carry an invisible `Interactive` painter alongside their visual painter, and a new `ui.HitTest(tree, x, y)` walks the rendered tree to find which one (if any) was tapped. This makes the main menu's tap handling a direct consumence of the exact same tree used to draw it, and the mechanism is reusable by the deferred options/pause/win/game-over follow-up work without further library changes.

## User Stories

1. As a player, I want the main menu's title and buttons to look pixel-identical to today across all window sizes, so that this internal rewrite causes no visible regression.
2. As a player, I want tapping/clicking New Game, Options, or Quit to keep working exactly as before, so that the rewrite is invisible to me.
3. As a player, I want keyboard navigation (Up/Down/Enter) on the main menu to be completely unaffected, so that an internal rendering change doesn't touch how I already play.
4. As a developer, I want the main menu's title+button layout expressed as one declarative tree instead of three independently-hand-computed pixel formulas (draw, bounds-for-draw-highlighting, bounds-for-tap), so that there's a single source of truth for its geometry.
5. As a developer, I want drawing and hit-testing to consume the same tree shape, so that a future change to the main menu's layout (e.g. adding a fourth button) can't desync visuals from tap targets the way hand-rolled bounds functions could.
6. As a developer, I want `menu.lua` to stay state-agnostic (no `gamestate` coupling), so that it keeps its current pure-view role and `main.lua` keeps owning all state mutation.
7. As a developer extending `lib/ui` for a future screen, I want a generic, reusable way to attach a tap handler to any node, so that I don't need to reinvent hit-testing per screen.
8. As a developer extending `lib/ui` for a future screen, I want the new interactivity mechanism to be additive and non-breaking, so that existing single-painter call sites and tests across `lib/ui` keep working untouched.
9. As a developer working on the deferred options/pause/win/game-over follow-up, I want the `Interactive` painter + `ui.HitTest` groundwork already in place, so that I can reuse it without redesigning hit-testing again.
10. As a developer, I want a behavior-level test that exercises the real tree-build + hit-test path (not just raw pixel-bounds assertions), so that the test catches wiring bugs (wrong callback attached to wrong button) as well as geometry bugs.
11. As a developer, I want the new `Interactive` painter kind and `ui.HitTest` covered by `lib/ui`'s own test suite, so that the library's behavior is verified independently of any one screen that uses it.

## Implementation Decisions

**Scope**: this PRD covers only the main menu (`menu.lua`'s `draw_main_menu`/`main_menu_button_bounds` and `main.lua`'s `state:in_menu()` tap branch). Options, pause, win, and game-over screens are explicitly untouched — see Out of Scope.

- **Main menu tree shape**: the root frame drops the current `board_x`/`board_y` anchoring entirely (the board square has no visual presence on this screen — it's just a full-window background fill) and becomes a plain full-window-sized, centered column: `w-<winW> h-<winH> center` containing a `col gap-N center` with a title `Leaf` and three button `Node`s, mirroring `game/lib/ui/example/main.lua`'s structure (each button is a Rectangle-painted outer `Node` wrapping a centered Text `Leaf`, per the example's "background + centered content" pattern).
- **Sizing stays pixel-identical**: font size, button width, and button height keep the exact current formula derived from `menu.lua`'s private `board_metrics()` (`board_px = floor(min(w,h)*0.8)`, `tile_px = floor(board_px/GRID_SIZE)`, `font_sz = max(12, floor(tile_px*0.30))`, etc.) — only `board_x`/`board_y` (the anchor position) stop being used; the size numbers feed straight into the new tree's class-string tokens (e.g. `w-<btn_w> h-<btn_h>`). `menu.lua`'s `board_metrics()` duplicating `renderer/board.lua`'s `M.metrics()` is a known, separate issue, left untouched (see Out of Scope).
- **`lib/ui` core gets one additive, non-breaking extension**: `game/lib/ui/layout/frame.lua`'s `Frame` gains an optional `painters` array field alongside its existing singular `painter` field. All existing single-painter call sites and tests (`frame.lua`, `compute.lua`, `painter.lua`, `builder.lua`, and their `*_test.lua` files, plus `game/lib/ui/example/main.lua`) are untouched and keep working exactly as before.
- **New `Interactive` painter kind**, added to `game/lib/ui/painter/painter.lua`: `painter.Interactive{ onTap = fn }`. It carries only a callback. `Measure`/`Wrap` return zero size for it (it never affects layout), and `Draw` is a no-op for it (it's invisible — it only matters to the new hit-test walk).
- **New `ui.HitTest(tree, x, y)`**, added to `game/lib/ui/layout/ui.lua`: walks `tree.Commands` back-to-front (i.e. in reverse insertion order, so a later-drawn/topmost node wins over anything beneath it at the same point), and returns the first `Interactive` painter's callback whose box contains `(x, y)`, or `nil` if none matched. It does not invoke the callback — it's a side-effect-free lookup; the caller decides whether/when to call the result. An O(n) linear scan over `Commands` is acceptable for now; a quadtree or type-filtered sublist is noted as a possible future optimization, not built here.
- **`menu.lua` stays state-agnostic.** It does not require `gamestate` and never calls `state:*` itself. Its main-menu builder accepts a `callbacks` table shaped `{ on_new_game = fn, on_options = fn, on_quit = fn }`; `main.lua` supplies closures that do exactly what its current tap handler already does today (e.g. for Options: `state:keypressed("down"); state:keypressed("return")`) — `gamestate.lua` requires zero changes.
- **Module boundary** — `menu.lua` exposes two entry points, replacing the old `draw_main_menu`/`main_menu_button_bounds` pair:
  - `M.draw_main_menu(cursor)` — same signature as today. Builds the tree (Interactive painters are irrelevant here since `Draw` no-ops them), runs `ui.DrawTree`, loops `tree.Commands` drawing the visual painters.
  - `M.main_menu_hit_test(cursor, callbacks, x, y)` — builds the same tree shape, this time wiring each button's `Interactive` painter to the matching entry in `callbacks`, runs `ui.DrawTree`, calls `ui.HitTest`, and invokes the matched callback if any.
  - `main_menu_button_bounds()` is removed entirely — nothing else calls it once `main.lua`'s tap branch is rewritten.
- **`main.lua` change**: the `state:in_menu()` branch inside `handle_tap()` is rewritten to build a `callbacks` table (the same three closures described above) and call `menu.main_menu_hit_test(state:menu_cursor(), callbacks, x, y)`, replacing the current `menu.main_menu_button_bounds()` + manual `hit()` loop for this one branch only.

## Testing Decisions

- Tests should exercise observable behavior (does tapping a button's known on-screen position invoke the right action) rather than internal structure, consistent with the rest of this codebase's test style (`tests/test_menu.lua`, `tests/test_main_menu.lua`).
- **`tests/test_menu.lua`**: replace the previously-considered pixel-bounds assertion (now moot, since `main_menu_button_bounds()` is removed) with a behavior test — build the main-menu tree with stub/spy callbacks via `menu.main_menu_hit_test`, at the three buttons' known center coordinates (derived the same way the existing `pause_button_bounds` test derives expectations) plus one deliberate miss point, and assert the correct stub fired (or none did for the miss). This both verifies geometry and verifies the right callback is wired to the right button in one test.
- **`lib/ui`'s own suite** (alongside `builder_test.lua`, `ui_test.lua`, `compute_internals_test.lua`) gains new tests, registered in `tests/test_all.lua`:
  - The `Interactive` painter kind: `Measure`/`Wrap` return zero.
  - `ui.HitTest`: back-to-front precedence when two nodes' boxes overlap (the later/topmost one wins), a clean miss returns `nil`, and a hit returns the expected callback.
- **Unaffected, left as-is**: `tests/test_main_menu.lua` (gamestate keyboard-navigation tests — keyboard nav is untouched by this PRD) and `tests/test_menu.lua`'s existing `pause_button_bounds`/`pause_icon_bounds` tests.

## Out of Scope

- **Options, pause, win, and game-over screens.** They keep their current hand-math `draw_*`/`*_button_bounds` + `main.lua` `hit()` pattern untouched in this PRD. A follow-up PRD will rebuild them on the same `lib/ui`/`Interactive`/`ui.HitTest` groundwork, and must decide then whether their dimmed overlay stays anchored to the literal board square (current behavior) or becomes a full-screen overlay — that decision is intentionally deferred, not made here.
- **`menu.lua`'s `board_metrics()` vs `renderer/board.lua`'s `M.metrics()` duplication.** These two functions are currently byte-for-byte identical. Unifying them is a separate cleanup, not bundled into this PRD.
- **Touch usability fixes** (`docs/prd/triage/touch-usability-fixes.md`). The `Interactive` painter + `ui.HitTest` mechanism built here is reusable groundwork for that PRD's options-screen tap handling and pause-button repositioning work, but this PRD does not fix either of those reported bugs.
- **Performance optimization of `ui.HitTest`'s O(n) scan** (quadtree, type-filtered sublists) — noted as possible future work only, not built here.
- **`pause_icon_bounds` repositioning and win-particle rendering** — unrelated to this PRD, untouched.

## Further Notes

This PRD was originally registered without a grilling session, at the user's explicit request, as a placeholder. This document reflects the outcome of that grilling session: all of the original placeholder TBDs (scope, hit-testing design, `board_metrics()` handling, API contract) have been resolved as recorded above. Implementation may proceed against this PRD.
