---
title: "Generic Menu Screen"
description: "Replace the duplicated cursor/keypress/tap/activate logic across main_menu/pause/win/game_over/options, and menu.lua's five bespoke tree builders, with one generic item-list mechanism."
status: needs-triage
---

## Problem Statement

`main_menu_screen.lua`, `pause_screen.lua`, `win_screen.lua`, `game_over_screen.lua`, and `options_screen.lua` each independently reimplement the same shape: a cursor (or focused row), Up/Down to move it (clamped or wrapped), Return to activate whatever is current, and a tap handler that dispatches to a per-item action. Each screen's `activate()`/`tap_row()` function is a hand-written switch over a numeric cursor value mapping to `host:promote`/`host:replace`/`host:dismiss`/`host:quit` calls. Adding a sixth menu-shaped screen means copy-pasting this pattern a sixth time.

`menu.lua` mirrors the duplication one layer down: `build_main_menu_tree`, `build_options_tree`, `build_win_tree`, and `build_game_over_tree` each independently build a near-identical `lib/ui` tree (full-window background, centered column, title, N buttons), differing only in title text, button labels/count, and background color. `pause_screen.lua` is the holdout that never made it onto this pattern at all — it still draws via hand-rolled `love.graphics` calls (`menu.draw_pause`) and hit-tests via a manually maintained bounds array (`menu.pause_button_bounds`), a gap PRD 019 explicitly flagged and deferred ("Options, pause, win, and game-over screens... A follow-up PRD will rebuild them on the same `lib/ui`/`Interactive`/`ui.HitTest` groundwork").

As a developer adding or modifying a menu-shaped screen today, there's no single place that owns "a list of selectable things, navigated by keyboard or tap" — that behavior is re-derived five times, with `options_screen.lua`'s focus-and-cycle-a-value variant as a sixth near-miss (same cursor/focus shape, different activation semantics).

## Solution

Introduce one generic item-list mechanism used by all five screens:

- A new module, `game/menu_screen.lua`, owns the generic screen-side mechanics: cursor state, Up/Down (clamped or wrapped, configurable), Return (activates the current item), Left/Right (cycles a value-bearing item), and tap dispatch — all driven by an `items` list rather than a per-screen hand-written switch.
- `menu.lua` gains one generic item-list tree/draw/hit-test trio, replacing `build_main_menu_tree`, `build_options_tree`, `build_win_tree`, `build_game_over_tree`, and Pause's hand-rolled `draw_pause`/`pause_button_bounds` entirely. Pause moves onto the same full-window `lib/ui` tree pattern the other four already use — closing the gap left open since PRD 019.
- Each item in the list is one of two kinds, expressed through a single shared shape: a plain action item (`label` + `on_activate`, fires immediately on tap or Return — main_menu/win/game_over/pause's buttons) or a value-cycling item (`label` + `value` + `on_left`/`on_right`, focus-then-cycle on tap, cycle on Left/Right — options' rows). A non-focusable decorative item (`focusable = false`, e.g. options' instructional hint line) is skipped by cursor movement and never activated.
- Each of the five concrete screen modules shrinks to: build its `items` list (closures over `host`/`game` for actions, exactly as today's `activate()` closures already do), pick its title/background/wrap config, hand both to `game/menu_screen.lua` and `menu.lua`'s generic builder, and layer any one-off extra key binding (Pause's Escape, Game Over's any-arrow-key-activates, Options' Escape) on top of the generic mixin's `keypressed`.
- The one deliberate visible change: Pause's overlay, today a dim rectangle anchored to the literal board square with buttons positioned relative to it, becomes a full-window dim overlay with a centered button column — matching how Win and Game Over already render. Everything else (labels, order, keyboard/tap behavior, persistence) is unchanged.

## User Stories

1. As a player, I want every existing menu (Main Menu, Pause, Win, Game Over, Options) to behave identically after this refactor — same keys, same tap targets, same labels, same order — so the rewrite is invisible to me except where explicitly noted.
2. As a player, I want Up/Down to move the highlighted item on Main Menu, Pause, Win, and Game Over, clamped at the top and bottom exactly as today.
3. As a player, I want Up/Down on Options to keep wrapping at both ends, exactly as today.
4. As a player, I want Return to activate whatever item is currently highlighted, on every menu, exactly as today.
5. As a player, I want tapping a button to activate it immediately regardless of which item was previously highlighted, on Main Menu, Pause, Win, and Game Over, exactly as today.
6. As a player, I want tapping an unfocused Options row to focus it (not activate it), and tapping the already-focused row to cycle its value forward, exactly as today.
7. As a player, I want Left/Right on a focused Options row to cycle its value immediately, with no confirm step, exactly as today.
8. As a player, I want Escape to dismiss the Pause screen and the Options screen, exactly as today.
9. As a player, I want any arrow key (not just Up/Down) to restart from the Game Over screen, exactly as today.
10. As a player, I want the Win screen's particle burst to keep appearing and animating exactly as today, unaffected by this refactor.
11. As a player, I want all four persisted settings (Win Tile, Theme, Animations, Effects) to keep saving and restoring exactly as today.
12. As a player, I want the Pause screen's overlay to now dim the whole window and center its four buttons in the middle of the screen, instead of dimming and anchoring only over the board square as it does today — a deliberate visual change that brings Pause in line with how Win and Game Over already render.
13. As a developer, I want a single generic module (`game/menu_screen.lua`) that owns cursor movement, key dispatch, and tap dispatch against an `items` list, so a sixth menu-shaped screen never needs to reimplement this from scratch.
14. As a developer, I want `game/menu_screen.lua` to know nothing about `love2d`, `host`, or any specific screen's domain (game state, settings, persistence) — it only knows about `items`, a cursor, and a couple of config flags — so it's testable in complete isolation and reusable by any future menu-shaped screen.
15. As a developer, I want one shared item shape (`label`, optional `value`, `on_activate`, `on_left`, `on_right`, `focusable`) that expresses both "plain action button" and "focus-then-cycle-a-value row," so I don't have to choose between two incompatible generic mechanisms depending on which kind of menu I'm building.
16. As a developer, I want plain action items to activate immediately on tap regardless of current focus, and value-cycling items to require focus-then-tap-again (or Left/Right) to change, so the existing, different tap semantics of "menu" vs "settings list" are preserved exactly under one schema.
17. As a developer, I want non-focusable decorative items (e.g. Options' "Up/Down to focus a row..." hint line) expressible directly in the `items` list as `focusable = false`, so cursor movement skips them without the screen module needing special-case logic.
18. As a developer, I want wrap-vs-clamp cursor behavior to be an explicit config flag passed when a screen builds its item list, defaulting to that screen's current behavior, so unifying the mechanism causes zero behavior change unless a screen's config is deliberately set otherwise.
19. As a developer, I want one-off extra key bindings (Pause's Escape, Game Over's any-arrow-activates, Options' Escape) to stay as a small override in each screen's own `keypressed`, checked before falling through to the generic mixin's `keypressed`, so the generic mixin doesn't grow a config knob for every screen's individual quirk.
20. As a developer, I want `menu.lua` to gain one generic item-list tree builder, draw function, and hit-test function, parameterized by title, background color, and the `items` list, replacing `build_main_menu_tree`, `build_options_tree`, `build_win_tree`, and `build_game_over_tree` outright.
21. As a developer, I want Pause's hand-rolled `draw_pause` and `pause_button_bounds` deleted entirely, with Pause's view rebuilt on the same generic `lib/ui` tree/hit-test mechanism as the other four screens, closing the gap PRD 019 left open.
22. As a developer, I want Pause's overlay to become a full-window dim + centered column (matching Win/Game Over) specifically because it now goes through the same generic builder as those two — not as an incidental side effect, but as a deliberate, agreed visual unification.
23. As a developer, I want every screen's font sizing and button sizing to keep using the exact same `board_metrics()`-derived formulas they use today, so this refactor changes who calls the sizing math, not the math itself.
24. As a developer, I want each concrete screen module (`main_menu_screen.lua`, `pause_screen.lua`, `win_screen.lua`, `game_over_screen.lua`, `options_screen.lua`) reduced to: building its `items` list with action closures over `host`/`game`, picking its title/background/wrap config, and wiring any one-off extra key, so the "interesting" part of each screen (what it does, not how input/rendering plumbing works) is the only thing left to read.
25. As a developer, I want a single standardized cursor accessor (`:cursor()`) exposed by every one of the five screens, replacing today's inconsistent `cursor()`/`pause_cursor()`/`focused_row()` names, so calling code and tests don't need to remember a different accessor name per screen.
26. As a developer, I want the externally observable cursor to be 0-based on every screen, including Options (today internally 1-based via `optionsmodel.lua`'s row indices), so all five screens share one indexing convention.
27. As a developer, I want `optionsmodel.lua`'s focus/cursor-movement responsibility (today's `focus_row`/`up`/`down`) retired in favor of the generic mixin's cursor, with `optionsmodel.lua` narrowing to (or being replaced by) per-row value-cycling helpers invoked from each row's `on_left`/`on_right` closure, so there's no second, competing cursor implementation living inside the Options screen.
28. As a developer, I want `game_screen.lua` (the board/playing screen) completely untouched by this refactor — it isn't a menu-shaped screen and has no items/cursor — so this PRD's blast radius stays confined to the five menu screens plus `menu.lua` and the new `game/menu_screen.lua`.
29. As a developer, I want `win_screen.lua`'s particle spawn/update/draw logic to stay exactly where it is today, layered on top of (not absorbed into) the generic mechanism, since particles are a screen-local effect unrelated to item navigation.
30. As a developer testing this refactor, I want `game/menu_screen.lua` covered by isolated unit tests using stub items (spy `on_activate`/`on_left`/`on_right`) with no `love2d`, `host`, or real screen involved, so the generic mechanism is proven correct independent of any one screen.
31. As a developer testing this refactor, I want `menu.lua`'s new generic builder covered by tree-build/draw/hit-test tests in the same style as the per-screen tests it replaces, so the view-layer behavior (which button is where, which tap hits which item) is verified the same way it always has been.
32. As a developer testing this refactor, I want every existing per-screen behavior test (`test_main_menu_screen.lua`, `test_pause_screen.lua`, `test_win_screen.lua`, `test_game_over_screen.lua`, `test_options_screen.lua`) ported to assert the same observable host-call behavior against the new, thinner screen implementations, so no coverage is lost in the move.
33. As a developer running `make test-game`, I want the full suite green throughout this refactor, one cycle at a time, consistent with this codebase's existing TDD workflow.

## Implementation Decisions

- **New module `game/menu_screen.lua`**: exposes `menu_screen.new(config)` returning a Screen-shaped table (duck-typed against `screen_manager.lua`'s interface — `enter`, `keypressed`, `tap`, `draw` delegated to the generic builder, `cursor()`).
  - `config.items`: an ordered array of item tables, each `{ label, value = nil, on_activate = nil, on_left = nil, on_right = nil, focusable = true }`.
    - A plain action item sets `label` + `on_activate`; it fires on Return (when current) or immediately on tap (regardless of current cursor).
    - A value-cycling item sets `label` + `value` + `on_left`/`on_right`; Left/Right (when current) calls the matching handler; tapping it when unfocused only moves the cursor to it, tapping it again while already focused calls `on_right` (matching today's Options "second tap cycles forward" behavior).
    - A decorative item sets `focusable = false` and is skipped entirely by cursor movement (Up/Down never lands on it) and by tap activation.
  - `config.wrap` (boolean): Up/Down wraps at both ends when true, clamps when false. Each screen passes the flag matching its current behavior (`true` for Options, `false` for Main Menu/Pause/Win/Game Over).
  - `config.cursor_start` (default `0`): initial cursor position set on `enter()`.
  - Cursor is 0-based and only ever lands on focusable items.
  - `menu_screen.lua` has no dependency on `love2d`, `host`, or any concrete screen — it is constructed once per screen instance and is pure logic over the `items` array.
- **`menu.lua` generic builder**: one new tree-builder/draw/hit-test trio (mirroring the existing `M.x_tree`/`M.draw_x`/`M.x_hit_test` naming convention already used for the four screens it replaces), parameterized by a small per-screen spec (title text, background color, full-window vs centered-column layout — all five screens use the full-window layout after this PRD) plus the `items` array and current cursor. Item rendering branches on whether `value` is present (plain button vs. label+value row, reusing the existing visual treatment from `build_main_menu_tree`'s buttons and `build_options_tree`'s rows respectively) and on `focusable` (a non-focusable item renders as plain text, never highlighted).
  - `build_main_menu_tree`, `build_options_tree`, `build_win_tree`, `build_game_over_tree`, `draw_pause`, and `pause_button_bounds` are all deleted, replaced by calls into the one generic trio.
  - Sizing math (`menu_sizes()`, `board_metrics()`-derived font/button dimensions) is unchanged; the generic builder consumes it exactly as today's per-screen builders do.
- **Pause's overlay becomes full-window**: dim rectangle covers the whole window (not just the board square), and its four buttons render in a centered column, matching Win/Game Over's existing layout. This is the one deliberate visual change in this PRD.
- **Screen-level extra key overrides**: each of Pause (Escape), Options (Escape), and Game Over (any arrow key activates) keeps a small `keypressed` override in its own module that checks its one-off binding first, then falls through to calling the generic mixin's `keypressed` for everything else. The generic mixin itself only ever handles Up/Down/Return/Left/Right and tap.
- **Standardized cursor accessor**: every one of the five screens exposes `:cursor()` (backed by the generic mixin), replacing today's `cursor()` (Main Menu/Win, unchanged in name), `pause_cursor()` (Pause, renamed), and `focused_row()` (Options, renamed). This is a deliberate, agreed change to each screen's public interface, not an internal-only detail.
- **`optionsmodel.lua` narrows**: its `focus_row`/`up`/`down` responsibilities are retired (superseded by the generic mixin's cursor/wrap handling); it keeps (or is reduced to) the per-row value-cycling logic (`index_of`, computing the next/previous value for a row) invoked from each Options item's `on_left`/`on_right` closure. The exact shape of what remains is an implementation-time call, flagged here for review rather than fully pre-specified.
- **Action closures stay screen-owned**: each screen module still builds its own `on_activate`/`on_left`/`on_right` closures over `host`/`game`/`make_x` factories at construction time, exactly as today's `activate()` functions already do — the generic mixin never receives `host` or `game` directly, only the closures.
- **`game_screen.lua` is untouched** — it has no items/cursor and isn't part of this mechanism.

## Testing Decisions

- Tests assert observable behavior, not internal structure — consistent with this codebase's established testing philosophy (`tests/test_menu.lua`, `tests/test_screen_manager.lua`, and every screen-stack-era PRD).
- **New `tests/test_menu_screen.lua`**: unit tests for `game/menu_screen.lua` against stub `items` (spy `on_activate`/`on_left`/`on_right`, no `love2d`/`host`/real screen involved) — cursor clamp at both ends, cursor wrap at both ends, Return activating the current item, tap activating a plain item regardless of current cursor, tap-to-focus then tap-to-cycle on a value item, Left/Right cycling a value item, and cursor movement skipping non-focusable items.
- **`tests/test_menu.lua`**: existing tests for `main_menu_hit_test`/`options_hit_test`/`win_hit_test`/`game_over_hit_test` are ported to exercise the new generic builder instead of the four bespoke ones; new tests cover Pause's tap targets now going through the same generic hit-test mechanism instead of `pause_button_bounds`.
- **Per-screen tests** (`tests/test_main_menu_screen.lua`, `tests/test_pause_screen.lua`, `tests/test_win_screen.lua`, `tests/test_game_over_screen.lua`, `tests/test_options_screen.lua`): ported to assert the same host-call behavior as today (which `host:promote`/`host:replace`/`host:dismiss`/`host:quit` fires for a given key/tap), updated only where the public accessor name changed (`pause_cursor()` → `cursor()`, `focused_row()` → `cursor()`) or where Pause's tap coordinates need to follow its new full-window button layout.
- `make test-game` stays green throughout, one cycle at a time, per this codebase's TDD workflow.

## Out of Scope

- `game_screen.lua` and the board/playing screen — not a menu-shaped screen, untouched.
- Any change to `settings.lua`/`config.lua` or persistence.
- The separate `flatten-renderer-into-screens.md` triage PRD (renderer/board/hud flattening) — unrelated, untouched by this PRD.
- Any visual change beyond Pause's overlay going full-window — no new screens, no new menu items, no styling overhaul of existing ones.
- Win screen's particle system — stays exactly as it is, layered on top of the generic mechanism.

## Further Notes

This PRD was developed through a `/grill-me` session. Key decisions resolved during grilling, in order:

- Scope is all five existing menu-shaped screens (Main Menu, Pause, Win, Game Over, Options) in one PRD, not a subset.
- The generic mechanism extends into `menu.lua`'s view layer (a new generic tree/draw/hit-test trio), not just the screen-module input glue — superseding the "menu.lua is out of scope" framing used by PRDs 019/025/031.
- Pause's long-deferred migration onto `lib/ui` (flagged as future work since PRD 019) lands inside this PRD rather than as a separate follow-up, after an initial round of back-and-forth on that exact point.
- One unified item schema covers both "plain action button" and "focus-then-cycle-a-value row," rather than two separate generic mechanisms.
- Wrap-vs-clamp is configurable per screen, defaulting to each screen's current behavior, so unification itself causes zero behavior change there.
- One-off extra key bindings (Escape, any-arrow-activates) stay as screen-level overrides on top of the generic mixin rather than becoming generic config knobs.
- Pause's overlay becomes full-window to match Win/Game Over — the one deliberate, agreed visual change in this PRD, resolving the exact question PRD 019 deferred.
