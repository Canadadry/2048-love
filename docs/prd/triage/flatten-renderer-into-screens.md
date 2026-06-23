---
title: "Refactor: Flatten renderer/* into the screens that own it"
description: "game/renderer/init.lua has decayed into dead code and a leaky facade since the screen-stack refactor (PRD 031); fold its live logic into game_screen.lua and flatten its submodules to match the rest of the codebase."
status: needs-triage
---

## Problem Statement

`game/renderer/init.lua` was created by PRD 015 as a thin facade over `board.lua`, `tile_draw.lua`, and `hud.lua`, exposing one orchestration entry point (`draw()`) that composed the board background, tiles, animating tiles, the score HUD, and (at the time) the win/game-over/pause overlays.

Since then, PRD 031 (the screen-stack refactor) moved every overlay (Pause, Win, Game Over, Options, Main Menu) into its own `game/screens/*` module that draws itself via `menu.lua`, independent of `renderer`. `game_screen.lua` now calls `renderer.draw(cells, score, false, false, anim_tiles, 0, false, 0, {})` — `game_over`, `win`, and `paused` are permanently `false`, and `cursor`/`pause_cursor`/`win_particles` are permanently `0`/`0`/`{}`. The branches in `renderer/init.lua` that call into `menu.lua` to draw those overlays are unreachable.

At the same time, the facade never fully held: `menu.lua` requires `renderer.board` directly for layout sizing, and `game_screen.lua` requires `renderer.hud` directly for hit-testing — both bypass `renderer/init.lua` entirely. The "facade" only actually mediates one caller (`game_screen.lua`'s `draw()`/`set_tileset()`, and `main.lua`'s `update()`).

Finally, `renderer/` is one of only two directories under `game/` (alongside `lib/ui`) — every other single-concern module (`grid.lua`, `tile.lua`, `swipe.lua`, `menu.lua`, `settings.lua`) is a flat file. Now that the screen-stack architecture gives each screen ownership of its own drawing, there's no remaining reason for a `renderer` namespace: the board/tile/HUD composition that's left is specific to `game_screen.lua` and should live there, not behind a module boundary nobody fully respects.

A `font_cache` + `get_font(size)` helper is also duplicated identically across `renderer/init.lua`, `hud.lua`, and `menu.lua` — discovered while tracing this refactor, since inlining `renderer/init.lua`'s composition into `game_screen.lua` would otherwise create a fourth copy.

## Solution

Delete `game/renderer/` (directory and `init.lua`) entirely. Flatten its three submodules to `game/board.lua`, `game/hud.lua`, `game/tile_draw.lua` — plain, flat, single-concern modules at the same tier as `grid.lua` and `tileset.lua`. `game_screen.lua` requires these directly and inlines the live part of `renderer/init.lua`'s old `draw()` (background, static tile grid, animating tiles, HUD) into its own `draw()` method. The dead `paused`/`win`/`game_over`/`cursor`/`pause_cursor`/`win_particles` parameters and the `menu.lua` require are deleted, not carried forward.

`hud.lua`'s `show_icon` parameter — already hardcoded `true` at every real call site — is deleted from its public API; the pause icon always renders.

The one behavior that must survive unchanged: the tileset's GIF animation clock (`tile_draw.lua`'s `anim_time`) keeps advancing every frame even while Pause/Win/Game Over is promoted on top of the board, exactly as it does today (today this works because `main.lua` calls `renderer.update(dt)` unconditionally, outside the screen-stack's focused-only dispatch). Once `game_screen.lua` owns calling `tile_draw.update(dt)` from its own `update(dt)`, that only works if `screen_manager.lua`'s `update(dt)` dispatch reaches every screen on the stack, not just the focused top — so `screen_manager.lua`'s `update(dt)` changes from top-only to stack-wide (top-to-bottom order), while `keypressed`/`resize`/mouse/touch dispatch stay exactly as PRD 031 left them (top-only). `main.lua` drops its `require("renderer")` and its `renderer.update(dt)` call — `love.update` just calls `host:update(dt)`, which now internally ticks the whole stack.

The duplicated `font_cache`/`get_font(size)` helper is extracted to a new `game/font_cache.lua`, used by `game_screen.lua`, `hud.lua`, and `menu.lua`.

This is a structural refactor only — no visible gameplay, visual, or input behavior changes. Same bar as PRD 015 and PRD 031: every existing behavior that has a test keeps passing once that test is rewritten against the new module layout.

## User Stories

1. As a developer reading `game/`, I want every single-concern module to be a flat file, so that `renderer/` isn't a one-off exception I have to remember exists.
2. As a developer, I want `game_screen.lua`'s `draw()` to directly show the full board/tile/HUD composition it performs, so that I don't have to jump into a separate facade module to see what actually gets drawn during gameplay.
3. As a developer, I want the dead `paused`/`win`/`game_over`/`cursor`/`pause_cursor`/`win_particles` parameters gone, so that nobody reading or extending the draw path has to puzzle out why a board-drawing function accepts overlay state that's always `false`/`0`/`{}`.
4. As a developer, I want `renderer/init.lua`'s now-unreachable `menu.lua` require and its `draw_pause`/`draw_win`/`draw_game_over` calls removed, so that the dependency graph reflects what code actually executes.
5. As a developer, I want `board.lua` and `hud.lua` to be required from one consistent path (`board`, `hud`) everywhere, so that `menu.lua` and `game_screen.lua` aren't reaching through a facade (`renderer.board`) for one call and importing the same module directly (`hud`) for another.
6. As a developer, I want `hud.lua`'s `show_icon` parameter removed, so that I don't have to trace whether some caller somewhere still passes `false` before treating "the icon always shows" as a safe assumption.
7. As a player, I want the tileset GIF animation to keep playing at the same rate while I'm on the Pause menu, looking at the Win screen, or looking at the Game Over screen, exactly as it does today, so that this refactor doesn't introduce a visible regression.
8. As a developer, I want `screen_manager.lua`'s `update(dt)` to reach every screen on the stack (not just the focused top), so that a screen sitting underneath an overlay (like `game_screen.lua` underneath `pause_screen.lua`) can still drive its own per-frame state (like the tileset animation clock) without `main.lua` needing a side-channel call outside the stack-dispatch model.
9. As a developer, I want `keypressed`/`resize`/mouse/touch dispatch in `screen_manager.lua` to remain top-only (unchanged from PRD 031), so that input handling semantics aren't disturbed by a change that's only about time-based ticking.
10. As a developer adding a future screen, I want to know that its `update(dt)` will run every frame regardless of whether it's focused or paused beneath an overlay, so that I don't write per-frame logic assuming it only runs while focused (the way `keypressed` does).
11. As a developer, I want `main.lua` to no longer require `renderer` at all, so that `main.lua`'s only remaining responsibilities are constructing the initial screen/manager and forwarding LÖVE callbacks, per PRD 031's intent.
12. As a developer, I want the duplicated `font_cache`/`get_font(size)` helper that currently exists three times (`renderer/init.lua`, `hud.lua`, `menu.lua`) consolidated into one `game/font_cache.lua`, so that font caching has one implementation instead of four (counting the one `game_screen.lua` would otherwise gain).
13. As a developer running `make test-game`, I want `tests/test_renderer_board.lua`, `tests/test_renderer_hud.lua`, and `tests/test_renderer_tile_draw.lua` renamed to `tests/test_board.lua`, `tests/test_hud.lua`, and `tests/test_tile_draw.lua`, so that test filenames match the flattened modules they cover, consistent with every other test in `tests/`.
14. As a developer, I want `tests/test_all.lua`'s suite list updated to the renamed test files, so that `make test-game` keeps running every suite after the rename.
15. As a developer, I want the existing `show_icon=false` tests in the HUD test file deleted along with the dead parameter, so that the test suite doesn't keep asserting behavior that's no longer reachable.
16. As a developer, I want a new test in `tests/test_screen_manager.lua` asserting that `update(dt)` reaches every screen on the stack in top-to-bottom order, so that this is a deliberately specified and verified behavior, not an incidental side effect of how `game_screen.lua` happens to be wired today.
17. As a developer, I want the existing `keypressed`-reaches-only-the-top-screen test in `tests/test_screen_manager.lua` to remain unchanged and passing, so that I have direct proof the input-dispatch asymmetry (top-only for input, stack-wide for update) actually holds and wasn't accidentally widened.
18. As a developer, I want `tests/test_game_screen.lua`'s existing `draw()` no-crash test to keep passing once `game_screen.lua` requires `board`/`tile_draw`/`hud` directly instead of `renderer`, so that I have a regression check that the inlined composition still runs end to end.
19. As a developer reviewing this change, I want zero changes to `menu.lua`'s tree-building or visual output, so that this refactor is reviewable purely as a structural move with no visual diff to eyeball.
20. As a developer reviewing this change, I want zero changes to any other screen module's (`pause_screen.lua`, `win_screen.lua`, `game_over_screen.lua`, `options_screen.lua`, `main_menu_screen.lua`) behavior, so that the blast radius is provably confined to `renderer/*`, `game_screen.lua`, `main.lua`, and `screen_manager.lua`.

## Implementation Decisions

- **Delete `game/renderer/` entirely** (the directory and `init.lua`). No module is left behind at that path.
- **Flatten submodules**: `game/renderer/board.lua` → `game/board.lua`, `game/renderer/hud.lua` → `game/hud.lua`, `game/renderer/tile_draw.lua` → `game/tile_draw.lua`. Their internal APIs (`board.metrics`, `board.cell_to_px`, `board.draw_background`, `tile_draw.set_tileset`, `tile_draw.update`, `tile_draw.tile_color`, `tile_draw.draw`) are unchanged except for the `show_icon` removal on `hud.lua`, below. `tile_draw.lua` keeps its name (not `tile.lua`) to avoid the existing collision with the animation-state module, per PRD 015's prior note.
- **`hud.lua` API change**: `M.draw(score, show_icon)` → `M.draw(score)`; `M.hit_test(score, show_icon, callbacks, x, y)` → `M.hit_test(score, callbacks, x, y)`; `M.hud_tree(score, show_icon, callbacks)` → `M.hud_tree(score, callbacks)`. The icon node is always built; no conditional branch remains.
- **Update every require path** that pointed at `renderer.board` or `renderer.hud` (currently `menu.lua`, `game_screen.lua`) to the flattened `board`/`hud` paths.
- **`game_screen.lua` becomes the sole owner of board/tile/HUD composition**: it requires `board`, `tile_draw`, `hud`, and `font_cache` directly. Its `draw()` method inlines what `renderer/init.lua`'s `draw()` used to do for the live path only: draw the board background, draw the static tile grid (skipping animation destinations), draw in-flight animating tiles, then call `hud.draw(score)`. The dead overlay branches and their parameters are not carried forward — `game_screen.lua`'s `draw()` takes no `paused`/`win`/`game_over`/`cursor`/`pause_cursor`/`win_particles` arguments at all, since it never needed them to be parameters in the first place (those screens draw themselves now).
- **`game_screen.lua` calls `tile_draw.set_tileset(config.TILESET)` from its own `draw()`**, same deferred-reload timing as today's `renderer.set_tileset()` call (PRD 020's pattern, unchanged).
- **`game_screen.lua` calls `tile_draw.update(dt)` from its own `update(dt)`**, replacing today's `main.lua`-driven `renderer.update(dt)`.
- **`screen_manager.lua`'s `update(dt)` becomes stack-wide**: instead of routing through the existing generic `dispatch()` helper (which only reaches the top of the stack), `SM:update(dt)` iterates every screen currently on the stack, top-to-bottom, calling `update(dt)` on each one that defines it (no-op if undefined, consistent with every other lifecycle hook). `SM:keypressed`, `SM:resize`, and all mouse/touch dispatch continue to use the existing top-only `dispatch()` helper, unchanged. This is a deliberate, confirmed asymmetry: only time-based ticking is stack-wide; everything else stays focused-only.
- **`main.lua` drops `require("renderer")` and its `renderer.update(dt)` call** from `love.update`. `love.update(dt)` becomes just `host:update(dt)`.
- **New `game/font_cache.lua`** exposing a `get_font(size)` function backed by a module-local cache (same memoization behavior as the three existing copies). `game_screen.lua`, `hud.lua`, and `menu.lua` require it instead of each keeping their own local `font_cache` table.
- **No PRD 031 testing-decision text is retroactively edited** — PRD 031 remains a historical record of what shipped at the time; this PRD documents the subsequent change to `screen_manager.lua`'s `update(dt)` dispatch on its own.

## Testing Decisions

- Tests assert observable behavior, not internal structure — consistent with PRD 015 and PRD 031's existing testing philosophy.
- **Rename** `tests/test_renderer_board.lua` → `tests/test_board.lua`, `tests/test_renderer_hud.lua` → `tests/test_hud.lua`, `tests/test_renderer_tile_draw.lua` → `tests/test_tile_draw.lua`. Update their `require("renderer.board")` / `require("renderer.hud")` / `require("renderer.tile_draw")` calls to the flattened paths.
- **Delete the `show_icon=false` test cases** in the renamed HUD test file (`"hud_tree with show_icon=false omits the icon entirely"` and `"draw with show_icon=false runs without erroring"`) — they test a parameter that no longer exists. Existing tests for the icon-present path are kept and updated to the new (param-less) call signature.
- **Update `tests/test_all.lua`'s suite list** to reference the three renamed files.
- **New test in `tests/test_screen_manager.lua`**: a case asserting `update(dt)` reaches every screen on the stack, in top-to-bottom order, regardless of pause/focus state — e.g. promote a second screen on top of a first, call `sm:update(dt)`, and assert both screens' `update` fired with the first screen's call recorded before the second's. Same style as the existing `"draw() skips screens below the topmost opaque screen"` case (stub screens with logging functions, assert call order).
- **No change needed** to the existing `"keypressed reaches only the top screen, not a paused one beneath"` test or any other existing `tests/test_screen_manager.lua` case — they continue to pass unmodified, serving as direct proof that the top-only/stack-wide asymmetry is real and intentional.
- **`tests/test_game_screen.lua`**: the existing `"draw() runs without erroring"` case (currently labeled `"Cycle 15: draw() delegates to the board/HUD renderer"`) continues to exercise `game_screen.lua`'s `draw()` end-to-end; it requires no behavioral change, only continuing to pass once `game_screen.lua`'s requires change from `renderer`/`renderer.hud` to `board`/`tile_draw`/`hud`. Its existing use of `require("renderer.hud")` for HUD hit-test setup is updated to `require("hud")`.
- **`tests/test_main.lua`**: its stub of `require("renderer").draw` is removed or updated, since `renderer` no longer exists as a module — `main.lua` no longer calls anything named `draw` directly (that responsibility moved fully into the screen stack via `host:draw()`), so this test's assertion needs to be re-pointed at whatever `main.lua` still does own (constructing the initial screen, forwarding LÖVE callbacks to `host`).
- No new tests are needed for `font_cache.lua` beyond what's implicitly covered by the existing draw-path tests (`test_board.lua`, `test_hud.lua`, `test_game_screen.lua`, `test_menu.lua`) continuing to pass — it's a pure memoization cache with no independent behavior worth isolating.

## Out of Scope

- Any visual or gameplay behavior change. This is a structural refactor; the bar is "every existing test that exercised a behavior still passes once rewritten against the new module layout," same as PRD 015 and PRD 031.
- Any change to `menu.lua`'s `lib/ui` tree-building or visual output.
- Any change to any screen module's behavior other than `game_screen.lua`'s draw/update wiring (`pause_screen.lua`, `win_screen.lua`, `game_over_screen.lua`, `options_screen.lua`, `main_menu_screen.lua` are untouched).
- Any change to `screen_manager.lua`'s `keypressed`, `resize`, or mouse/touch dispatch semantics — these remain top-only exactly as PRD 031 left them.
- Splitting this into two separate PRDs (one for the renderer flatten, one for the `screen_manager.lua` update-dispatch change) — they're causally linked here (the `screen_manager.lua` change only exists to preserve current animation behavior once `game_screen.lua` owns the tick), and splitting would create an awkward intermediate state where one PRD depends on the other landing first.
- Any change to `settings.lua`/`config.lua` or persistence.
- Any change to `tile.lua` (the per-tile animation state module, distinct from `tile_draw.lua`).

## Further Notes

This PRD was registered via a `/grill-me` session that traced the actual current call graph (who requires what, what parameters are live vs. dead) rather than relying on PRD 015's description of the prior state, which had already drifted from the code by the time of this grilling (PRD 015 claimed overlay rendering "already lived entirely in `menu.lua`" with "nothing overlay-related left in `renderer.lua` to extract" — but `renderer/init.lua` as it exists today still has `paused`/`win`/`game_over` branches calling into `menu.lua`; those became dead only later, once PRD 031 made `game_screen.lua` always pass `false`/`0`/`{}`).

The `screen_manager.lua` `update(dt)` change is the one piece of this refactor with a real (if narrow) design implication beyond cleanup: every future screen's `update(dt)` will now fire every frame regardless of whether that screen is focused or sitting paused beneath an overlay. This was explicitly weighed against the alternative (freezing the tileset animation while Pause/Win/Game Over is shown) and rejected in favor of preserving today's visible behavior. Anyone adding a new screen with per-frame side effects should be aware their `update(dt)` no longer implies "only runs while I'm on top."
