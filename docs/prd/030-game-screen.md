---
title: "Game Screen"
description: "Migrate gamestate.lua's PlayingState (grid, score, tile animation, swipe-to-move, win/game-over/pause promotion) onto the screen_manager stack as a standalone game_screen.lua module."
status: done
---

# Game Screen

## Problem Statement

The board/playing experience currently lives as `PlayingState` inside `gamestate.lua`, sharing a single `ctx` table (grid, score, tiles, queue, win_particles, win_seen) with `PausedState`, `WinState`, and `GameOverState` — those three states only *look* like overlays on top of the board because they share `ctx`, not because the architecture expresses "this sits on top of that." Per the parent [Screen Stack Refactor](screen-stack-refactor.md) PRD, this becomes an explicit `GameScreen` that owns the board outright and *promotes* Pause/Win/Game Over onto the stack above itself, instead of switching a shared `ctx` between sibling states.

This is the most complex of the four remaining screens (alongside [Main Menu](main-menu-screen.md), [Win](win-screen.md), [Game Over](game-over-screen.md)) and the one the other two overlay screens depend on, since they hold a reference back to it for `restart()`.

## Solution

Add `game/screens/game_screen.lua`, owning the grid, score, in-flight tile animations, and move queue — the part of today's `ctx` that isn't menu/options bookkeeping. It also owns its own `swipe.lua` instance, so move-by-swipe is entirely self-contained rather than `main.lua` owning one shared `swiper` across every screen.

On a move result:
- that wins the game (and hasn't been seen yet this game) → `host:promote(deps.make_win(self))`.
- that ends the game → `host:promote(deps.make_game_over(self))`.

On Escape, it defers pausing until any in-flight tile animation finishes (preserving today's `_pause_pending` flag behavior exactly), then `host:promote(pause_screen.new(host, self, deps.make_main_menu))` — `pause_screen.lua` already exists and is reused directly.

Since `win_screen.lua`, `game_over_screen.lua`, and `main_menu_screen.lua` don't exist yet (or may not, depending on build order), `GameScreen` takes a `deps` table of factory functions for them, the same pattern already used by `pause_screen.lua`'s `make_main_menu` (see Implementation Decisions for why this PRD uses a table here instead of flat args).

## User Stories

1. As a player, swiping or pressing arrow keys moves tiles exactly as today, with the same slide/merge animation timing.
2. As a player, my move input is ignored while a previous move is still animating, exactly as today (`PlayingState:keypressed` no-ops while `#ctx.tiles > 0`).
3. As a player, pressing Escape while tiles are mid-animation doesn't pause immediately — it pauses once the animation finishes, exactly as today.
4. As a player, any move queued mid-animation is discarded once a deferred pause actually opens, exactly as today (`ctx.queue = {}` before `ctx.switch("paused")`).
5. As a player, reaching the win tile opens the Win screen with the board frozen and visible underneath; reaching it again after Continuing does not reopen the Win screen this game.
6. As a player, a board with no legal moves left opens the Game Over screen with the board frozen and visible underneath.
7. As a player, tapping the pause icon in the HUD opens the same Pause screen as pressing Escape, and tapping anywhere else on the idle board does nothing — exactly as today, no new tap targets.
8. As a player, the HUD pause icon is always visible while playing, regardless of whether I've previously opened and closed Pause/Win/Game Over during this session.
9. As a player, resizing the window mid-animation snaps tiles to their final position instantly rather than continuing to animate at the new size, exactly as today (`PlayingState:resize`).
10. As a player, choosing "New Game" or "Restart" from Pause, Win, or Game Over resets this exact board (score, grid, animations, queue) in place, rather than tearing down and reconstructing the whole screen.
11. As a player, a move that both completes the win tile and leaves no further legal moves opens the Win screen, not Game Over, exactly as today.
12. As a player, the animated tileset's sprite-cycling never freezes — not while playing, not while Paused/Win/Game Over/Options/the Main Menu is on top — exactly as today, since it's a purely cosmetic clock that runs independently of any one screen.
13. As a player, if I resize the window while Pause/Win/Game Over/Options is open, my next swipe gesture on the board (after returning to it) uses the correct, up-to-date swipe sensitivity for the new window size.
14. As a developer, I want `GameScreen` to own its own `swipe.lua` instance rather than depend on a shared instance from `main.lua`, so the screen is fully self-contained and testable without `main.lua` wiring.
15. As a developer, I want `GameScreen` constructed with a single `deps` table of factories (`make_main_menu`, `make_win`, `make_game_over`) rather than hard `require`s of those modules or a long flat argument list, so this screen can be built, tested, and merged independently of their build order, while keeping the constructor readable now that there are three factories.
16. As a developer, I want `deps.make_win`/`deps.make_game_over` to receive the `GameScreen` instance itself as an argument (`deps.make_win(self)`), since those screens need a live reference back to call `restart()` — the same relationship `pause_screen.lua` already has with its injected `game` parameter.
17. As a developer, I want `GameScreen:restart()` exposed as a public method (resetting grid/score/tiles/queue, re-arming `win_seen`, and clearing any pending deferred-pause flag), so Pause/Win/Game Over screens can call it without reaching into this screen's internals.
18. As a developer, I want the existing "win seen" guard (don't reopen Win after Continue, for this game) to live as a flag this screen owns and exposes a way to set (e.g. `mark_win_seen()`), called by `WinScreen`'s Continue action before it dismisses.
19. As a developer, I want `GameScreen` to expose read accessors (`score()`, `cells()`, `anim_tiles()`, `is_animating()`) mirroring today's `Base` mixin, so tests and any future caller can observe board state without reaching into private fields — but *not* `win_particles()`/`pause()`/`win()`/`game_over()`/`cursor()`/`menu_cursor()`/`focused_row()`, since those concerns now belong entirely to other screens.
20. As a developer, I want `GameScreen:update(dt)` to *not* call `renderer.update(dt)` — that call moves to `main.lua`, running unconditionally every frame outside `ScreenManager` dispatch entirely, so the tileset animation clock never depends on which screen is focused.
21. As a developer, I want `GameScreen:resume()` (the lifecycle hook `ScreenManager` calls when this screen is dismissed back into focus) to recompute its swipe instance's threshold from the current window size, so a resize that happened while this screen was buried under an overlay self-corrects on return rather than requiring `ScreenManager` to broadcast `resize` to the whole stack.
22. As a developer testing this screen, I want every behavior `tests/test_gamestate.lua`'s board/move tests and `tests/test_pause.lua`'s deferred-pause/queue-discard tests currently exercise against `gamestate.new()`/`gamestate.new_from()` ported onto direct calls against `GameScreen`, so no coverage is lost in the move.
23. As a developer, I want `GameScreen:draw()` to draw only the board and HUD (no Pause/Win/Game Over overlay drawing) — those overlays are now separate screens drawn on top of this one by `ScreenManager:draw()`, not flags this screen branches on internally.
24. As a developer, I want `grid.lua`, `tile.lua`, `particle.lua`, and `swipe.lua` left completely unchanged — this PRD only relocates who owns and calls them.
25. As a developer, I want `pause_screen.lua`'s constructor migrated from flat args to a `deps` table *before* (or at the start of) this PRD's implementation, so `GameScreen` can construct it with the same `deps.make_main_menu` style it uses for its own factories, without a style mismatch between the two call sites.

## Implementation Decisions

- **`game/screens/game_screen.lua`**, interface: `M.new(host, deps)`.
  - `host`: the `ScreenManager` instance.
  - `deps`: a table of factories — `{ make_main_menu = fn, make_win = fn, make_game_over = fn }` — rather than flat positional arguments. With three injected screens, a table reads better than a four-argument positional signature; this intentionally breaks from `options_screen.lua`/`pause_screen.lua`'s simpler flat-arg precedent, which only ever needed one or two extra arguments each.
  - `deps.make_main_menu`: 0-arg factory, passed straight through to `pause_screen.new(host, self, { make_main_menu = deps.make_main_menu })` when Pause is promoted (see the prerequisite refactor below).
  - `deps.make_win(game)` / `deps.make_game_over(game)`: factories taking this screen instance, returning a `WinScreen`/`GameOverScreen` already wired to call back into it.
- **Prerequisite refactor — `pause_screen.lua`'s constructor.** Today's shipped, tested `M.new(host, game, make_main_menu)` must change to `M.new(host, game, deps)` with `deps.make_main_menu` used internally exactly where `make_main_menu` is used today, so both call sites in the codebase (`GameScreen` constructing `PauseScreen`, and any future direct construction) use the same `deps`-table convention. This is a small, mechanical, behavior-preserving change to `game/screens/pause_screen.lua` and `tests/test_pause_screen.lua`'s `new_screen()` helper — land it as its own commit before or at the very start of this PRD's TDD session, not as one of `GameScreen`'s own vertical slices.
- **Internal state**: `grid`, `score`, `tiles` (in-flight tile animations), `queue` (pending moves), `win_seen`, `pause_pending` — the same fields `ctx` holds today, now private to this screen instead of shared.
- **`restart()`**: reconstructs `grid` fresh, zeroes `score`, clears `tiles`/`queue`, resets `win_seen` to false, and resets `pause_pending` to false — same effect as today's `do_restart` plus an explicit (currently redundant, but cheap and defensive) reset of the deferred-pause flag, callable by Pause/Win/Game Over via their `game` reference.
- **`queue_move(dir)`**: same validation (`check.one_of`) and append-to-queue behavior as today.
- **`update(dt)`**: same drain-queue-when-idle / advance-tiles-and-fire-deferred-pause logic as today's `PlayingState:update`, restructured to promote Pause instead of `ctx.switch("paused")`. Does **not** call `renderer.update(dt)` — see "Tileset animation clock" below.
- **`keypressed(key)`**: arrow keys call the same `apply_move` logic (inlined or kept as a local helper) when idle; Escape sets `pause_pending` if tiles are mid-flight, otherwise promotes Pause immediately, clearing the queue either way before promoting — same ordering as today.
- **Win/game-over detection**: on a move result with `win == true` and `not self.win_seen`, promote via `deps.make_win(self)`; **only if that branch wasn't taken**, and `game_over == true`, promote via `deps.make_game_over(self)`. This preserves today's `elseif` behavior exactly: a move that both completes the win tile and leaves no further legal moves opens Win, never Game Over, on that move.
- **Own swipe instance**: constructed in `M.new` (or `enter()`), exposing the same `mousepressed`/`mousemoved`/`mousereleased`/`touchpressed`/`touchmoved`/`touchreleased` surface `main.lua` drives today, internally calling `queue_move` on a resolved swipe direction and falling through to a tap handler on a resolved tap. That tap handler checks **only** the HUD pause-icon hit-test — no other tap targets exist on the idle board, matching today's `main.lua` `handle_tap` exactly.
- **`resize(w, h)`**: finishes every in-flight tile immediately (`t:finish()`), same as today. Does not need to touch the swipe threshold itself — `resize` is only ever dispatched to this screen while it's focused, and resizing while focused already wants the threshold updated immediately, so this can call the same threshold recompute described under `resume()` below.
- **`resume()`**: recomputes the swipe instance's threshold (`swipe:set_threshold(math.min(love.graphics.getDimensions()) * 0.10)`), so a resize that happened while this screen was buried under Pause/Win/Game Over/Options self-corrects the moment focus returns here, rather than requiring `ScreenManager` to broadcast `resize` to the whole stack (accepted as low-stakes: a stale swipe threshold only affects swipe-vs-tap sensitivity, never correctness, for at most one resize-while-buried).
- **Tileset animation clock.** `renderer.update(dt)` (which only ticks `tile_draw`'s sprite-cycling clock) is explicitly *not* `GameScreen`'s responsibility, and is not called from `GameScreen:update(dt)`. It must keep running every frame, unconditionally, regardless of which screen is focused — exactly like today, where it's called directly from `main.lua`'s `love.update`, completely outside any per-state dispatch. The eventual `main.lua` rewiring (tracked by the parent PRD, out of scope here) must preserve this by calling `renderer.update(dt)` directly, not through `ScreenManager`.
- **HUD pause-icon visibility**: `GameScreen` always draws its icon, regardless of what's stacked above it. No `pause()`-driven visibility flag is needed — input dispatch only ever reaches the focused (top) screen, so the icon being visually present underneath an overlay is harmless; it can never be mistakenly tapped through one.
- **Read accessors**: `score()`, `cells()`, `anim_tiles()`, `is_animating()` — mirroring today's `Base` mixin, for testability and for any future caller that needs to observe board state. Deliberately *not* exposing `win_particles()`, `pause()`/`win()`/`game_over()` query methods, or `cursor()`/`menu_cursor()`/`focused_row()` — those are gone from this screen entirely, now owned by Win/Pause/Options respectively.
- **`draw()`**: draws background, cells, in-flight animated tiles, and the HUD — the same drawing currently done by `renderer.draw()` minus the `paused`/`win`/`game_over` branches at the bottom, since those are now separate screens.
- **`opaque()`**: not overridden — defaults to `true`. `GameScreen` is always the stack's opaque floor; Pause/Win/Game Over (all non-opaque) are promoted on top of it.

## Testing Decisions

- Tests assert observable behavior through the public screen interface (`queue_move`, `update`, `keypressed`, `restart`, `draw`), not internal `ctx`-shaped state — consistent with `tests/test_options_screen.lua` and `tests/test_pause_screen.lua`.
- **`tests/test_game_screen.lua`**, driven against a stub host (`promote`/`replace`/`dismiss`/`quit` spies) and a stub `deps` table (`make_main_menu`/`make_win`/`make_game_over` factories returning sentinels), so tests can assert `host:promote()` was called with the right sentinel without `pause_screen.lua`/`win_screen.lua`/`game_over_screen.lua` needing to be the real modules.
- A dedicated test for the win/game-over priority ordering: a move result with both `win` and `game_over` true promotes only the Win sentinel, never the Game Over one.
- A dedicated test for `resume()`: after a window-size change, calling `resume()` updates the swipe instance's threshold to match the new size.
- Behaviors ported from `tests/test_gamestate.lua`'s board/move-focused tests (move/merge/spawn/game-over/win detection via `grid.lua`, already covered by `tests/test_grid.lua` and unaffected) and from `tests/test_pause.lua`'s deferred-pause-during-animation and queue-discard-on-pause tests (escape mid-animation doesn't pause immediately; pauses once animation drains; queued moves are discarded when pause opens) — these explicitly move here from Pause's scope, since they're about `GameScreen`'s own update-loop sequencing, not anything `PauseScreen` itself does.
- `grid.lua`/`tile.lua`/`particle.lua`/`swipe.lua` unit tests (`tests/test_grid.lua`, `tests/test_tile.lua`, `tests/test_particle.lua`, `tests/test_swipe.lua`) are unaffected and untouched.
- `make test-game` must stay green throughout, one TDD cycle at a time, tracer bullet first.

## Out of Scope

- `main_menu_screen.lua`, `win_screen.lua`, `game_over_screen.lua` themselves — separate sibling PRDs; this PRD only injects factories for them.
- Wiring `main.lua` to construct the full `ScreenManager`/screen graph, retiring `gamestate.lua`/`statemachine.lua`, and moving the unconditional `renderer.update(dt)` call into the rewired `main.lua` — tracked by the parent [Screen Stack Refactor](screen-stack-refactor.md) PRD as a final step.
- Any change to `grid.lua`, `tile.lua`, `particle.lua`, `swipe.lua`, or `renderer/board.lua`/`renderer/tile_draw.lua`/`renderer/hud.lua`.
- The actual `pause_screen.lua` constructor migration commit itself is described here (since `GameScreen` depends on it), but executing that small refactor is a standalone first step, not a deliverable of this PRD's own vertical slices.

## Further Notes

This PRD is a sibling to [Main Menu Screen](main-menu-screen.md), [Win Screen](win-screen.md), and [Game Over Screen](game-over-screen.md). Of the four, this one should likely be implemented **last** (or at least, its win/game-over promotion logic finalized last), since `WinScreen`/`GameOverScreen` need a concrete shape for `GameScreen` to call back into (`restart()`, `mark_win_seen()`) — though factory injection means the actual build order isn't a hard blocker.

All previously open questions (HUD icon visibility, win/game-over priority, tileset animation clock ownership, swipe threshold staleness, constructor shape, and the `pause_screen.lua` consistency question) were resolved in a `/grill-me` session and are now reflected directly in Implementation Decisions above — none remain outstanding for this PRD.
