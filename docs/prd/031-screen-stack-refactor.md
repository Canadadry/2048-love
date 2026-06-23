---
title: "Screen Stack Refactor"
description: "Replace gamestate.lua's flat, ctx-sharing state machine with an explicit screen stack, where any screen can promote another screen on top of it (overlay, dismissible) or replace the whole stack (navigate away, no history)."
status: done
---

# Screen Stack Refactor

## Problem Statement

`gamestate.lua` currently models Menu, Playing, Paused, Win, Game Over, and Options as a flat set of state tables that all close over one shared `ctx` (grid, score, tiles, win_particles, queue). States don't actually nest or layer — Paused/Win/Game Over only *look* like overlays on top of the board because they happen to share `ctx` with Playing, not because the architecture expresses "this screen sits on top of that one." `statemachine.lua` only supports a single active slot (`switch()` fully replaces, mirroring PRD 008's explicit "no state stack" decision) — there's no way to express "go back to what was here before" except by hand-wiring each state's transition target.

`main.lua` also still owns per-screen branching directly: `love.draw()` and `handle_tap()` each have an `if/elseif` chain over `state:in_menu()` / `state:in_options()` / `state:paused()` / `state:win()` / `state:game_over()` that calls the right `menu.*` view function and wires the right `state:*` callback. Every new screen requires touching these chains in `main.lua` in addition to `gamestate.lua`.

## Solution

Replace the flat state machine with a real screen stack. A `ScreenManager` (owned by `main.lua`) holds a stack of `Screen` instances. Any screen can ask the manager to:

- **promote** another screen on top of it — the new screen becomes focused (receives input/update), the screen underneath is paused but stays on the stack, and is visible underneath if the promoted screen is a translucent overlay. The underlying screen can later be returned to by **dismissing** the top of the stack.
- **replace** — discard the entire stack and start fresh with a single new screen as the new root. No history is kept; there's nothing to dismiss back to.

This directly replaces today's implicit "shared ctx makes Paused/Win/Game Over look like overlays" trick with an explicit mechanism: the manager draws the stack bottom-up starting from the topmost *opaque* screen, so a translucent overlay screen (Paused/Win/Game Over) composites over whatever opaque screen is beneath it on the stack, with zero coupling between the two screens' internal data.

`main.lua` shrinks to wiring Love2D callbacks straight through to the `ScreenManager`, which dispatches only to the top (focused) screen. All of the screen-specific branching that currently lives in `main.lua`'s `love.draw()` and `handle_tap()` moves into each screen module.

Per the project's existing screens, this PRD covers: **Main Menu**, **Game** (the board/playing screen), **Options**, **Win**, and **Game Over** ("loose" in the request, kept as "Game Over" to match existing vocabulary — see README and `gamestate.lua`'s `GameOverState`). **Pause** is not in the request's explicit list but is an existing screen with no other natural home in this architecture, so it's folded into this refactor as a sixth screen — flagged as an assumption to confirm, not a unilateral scope addition (see Further Notes).

## User Stories

1. As a player, every existing screen (Main Menu, Game, Options, Pause, Win, Game Over) behaves identically after the refactor — same keyboard nav, same tap targets, same visuals, same persistence — so the rewrite is invisible to me.
2. As a player, when I open Pause, Win, or Game Over, the board stays visible (frozen) underneath the dimmed overlay, exactly as it does today.
3. As a player, dismissing Pause (Resume), Win (Continue), or Options (Back) returns me to exactly the screen I left, with its state intact.
4. As a player, choosing "Main Menu" from Pause, or "New Game" from the Main Menu, takes me to a clean screen with no leftover stack history to "back" into.
5. As a developer, I want a `ScreenManager` with two explicit, distinctly-named operations — promote (push, dismissible) and replace (discard stack, navigate away) — so that every screen transition in the app maps unambiguously to one of the two, instead of being re-derived per call site.
6. As a developer, I want the manager to own enter/exit/pause/resume lifecycle calls, so each screen module only implements the hooks it actually cares about (mirrors PRD 008's "missing methods are no-ops" decision).
7. As a developer, I want overlay screens (Pause/Win/Game Over) to require zero direct access to the Game screen's internal data (grid, cells, score) to render correctly, so that "the board shows behind the overlay" is a property of the stack/draw mechanism, not something each overlay screen has to special-case.
8. As a developer, I want each screen to own its own input handling (keypressed, tap/click hit-testing, swipe-drag-to-move), so `main.lua` no longer needs a per-screen `if/elseif` chain to know which view function and which callbacks to wire up.
9. As a developer adding a future screen (e.g. a settings sub-page, a confirmation dialog), I want to add one new screen module and one `promote`/`replace` call site, with zero changes to `ScreenManager`, `main.lua`, or any other screen.
10. As a developer, I want the Game screen's "pause is deferred until in-flight tile animation finishes" behavior (today's `_pause_pending` flag in `PlayingState`) preserved exactly, so animation correctness isn't regressed by the refactor.
11. As a developer, I want win-tile detection to still respect "only trigger the Win screen once per game" (today's `ctx.win_seen` flag), so reaching 2048 again after Continuing doesn't re-show the Win screen.
12. As a developer testing this refactor, I want `ScreenManager` covered by isolated unit tests in the same style as today's `test_statemachine.lua` (stack ordering of enter/exit/pause/resume, draw skipping to the topmost opaque screen, dispatch going only to the focused screen), so the stack mechanism itself is proven correct independent of any one screen.
13. As a developer, I want each screen's transition logic (which keys/taps trigger which `promote`/`replace`/`dismiss` call) tested against a stub/fake manager, so screen tests don't depend on real `ScreenManager` wiring, matching this codebase's existing behavior-level test style (`tests/test_main_menu.lua`, `tests/test_menu.lua`).

## Implementation Decisions

- **New module `screen_manager.lua`** (`game/`), replacing `statemachine.lua`. Owns an explicit stack (array) of screen instances, plus the shared no-op-default `Screen` prototype (mirrors `gamestate.lua`'s current `Base` table, which has no other home once `gamestate.lua` is retired).
  - `M.new(initial_screen)` — stack = `{ initial_screen }`, calls `initial_screen:enter()`.
  - `:promote(screen)` — calls `pause()` on the current top (no-op if undefined), pushes `screen` onto the stack, calls `screen:enter()`. The screen becomes focused; the previous top remains on the stack, underneath.
  - `:dismiss()` — pops the top screen, calling `exit()` on it, then calls `resume()` on the new top (no-op if undefined). Errors (or is a no-op — TBD, see Further Notes) if the stack would become empty.
  - `:replace(screen)` — calls `exit()` on every screen currently on the stack (top to bottom), clears the stack entirely, pushes `screen` as the sole new root, calls `screen:enter()`. There is nothing left to `dismiss()` back to.
  - `:update(dt)`, `:keypressed(key)`, `:resize(w, h)`, and all mouse/touch callbacks dispatch only to the top (focused) screen — same "active slot" dispatch model as today's `statemachine.lua`, just sourced from the top of a stack instead of a single slot.
  - `:draw()` walks the stack from the top downward to find the topmost screen whose `opaque()` returns true (default true if undefined), then draws every screen from that one up to the top, in bottom-to-top order. This is the one operation that touches more than the top of the stack — it's what makes overlay screens transparent to whatever opaque screen is beneath them, replacing today's implicit shared-`ctx` trick.
- **Screen interface** (duck-typed, like today's per-state tables): `enter()`, `exit()`, `pause()`, `resume()`, `update(dt)`, `draw()`, `keypressed(key)`, `resize(w, h)`, `mousepressed/mousereleased/mousemoved/touchpressed/touchmoved/touchreleased`, `opaque()`. Every hook is optional; the shared prototype no-ops anything a screen doesn't define, exactly like `gamestate.lua`'s current `Base`/dispatch pattern.
- **Host reference**: each screen receives the `ScreenManager` instance (the "host") at construction, so a screen calls `self.host:promote(...)`, `self.host:replace(...)`, `self.host:dismiss()` itself, instead of bubbling a transition request up through `main.lua` (which is how `ctx.switch` works today). `main.lua` never names a screen transition directly.
- **New `game/screens/` directory**, six modules (mirrors the existing precedent of `renderer/` getting its own directory once a subsystem outgrew a single file — PRD 015):
  - **`game_screen.lua`** — the board/playing screen. Owns grid, score, in-flight tile animations, and the move queue (the part of today's `ctx` that isn't menu/options bookkeeping). Exposes `restart()` (resets grid/score/tiles/queue in place — same approach as today's `do_restart`) for overlay screens to call. On a move result that wins (and hasn't been seen this game) or game-overs, calls `self.host:promote(WinScreen.new(self.host, self))` / `self.host:promote(GameOverScreen.new(self.host, self))`. On Escape, promotes `PauseScreen`, preserving the existing "wait for in-flight animation to finish" deferred-pause behavior. Owns its own swipe-drag instance (`swipe.lua`) so move-by-swipe is entirely self-contained, rather than `main.lua` owning one shared `swiper` across all screens.
  - **`main_menu_screen.lua`** — New Game → `host:replace(GameScreen.new(host))`; Options → `host:promote(OptionsScreen.new(host))`; Quit → `host:quit()` (or `love.event.quit()` directly — see Further Notes).
  - **`options_screen.lua`** — wraps today's `optionsmodel.lua` unchanged; Back/Escape → `host:dismiss()`, returning focus to whatever promoted it (Main Menu today).
  - **`pause_screen.lua`** — promoted by `game_screen.lua`. Resume → `host:dismiss()`. New Game → `game_screen:restart()` then `host:dismiss()`. Main Menu → `host:replace(MainMenuScreen.new(host))`. Quit → `host:quit()`.
  - **`win_screen.lua`** — promoted by `game_screen.lua`, holding a reference to it. Owns its own cursor and win-particle list (spawned in `enter()` when `config.EFFECTS_ENABLED`, updated/drawn by itself, not by `game_screen.lua`) — particles are a screen-local effect, not board state. Continue → marks the underlying game screen's win as seen, then `host:dismiss()`. Restart → `game_screen:restart()` then `host:dismiss()`.
  - **`game_over_screen.lua`** — promoted by `game_screen.lua`, holding a reference to it. Restart → `game_screen:restart()` then `host:dismiss()`.
  - `menu.lua`'s existing `lib/ui`-based tree builders (`main_menu_tree`, `options_tree`, `win_tree`, `game_over_tree`, plus the still-hand-rolled `draw_pause`/`pause_button_bounds`) are reused as-is by the corresponding screen module — this PRD does not touch the view layer built in PRD 019, only which module owns calling it and wiring its callbacks.
- **`gamestate.lua` and `statemachine.lua` are retired** (same disposition PRD 008 gave `gamestate.lua` the first time around), superseded by `screen_manager.lua` and `game/screens/*`.
- **`main.lua` becomes a thin Love2D callback forwarder**: `love.load` constructs the initial screen (`MainMenuScreen`) and the manager; `love.update`, `love.draw`, `love.keypressed`, `love.resize`, and all `love.mouse*`/`love.touch*` callbacks become one-line forwards to the matching `ScreenManager` method. The per-screen `if/elseif` chains in today's `love.draw()` and `handle_tap()` are deleted entirely — that branching now lives inside whichever screen is on top.
- **Settings/config access is unchanged**: screens read/write the global `config` module and `settings.lua` directly, exactly as `gamestate.lua`'s states and `options.lua` do today — this refactor doesn't touch config or persistence.

## Testing Decisions

- Tests assert observable behavior, not internal structure — consistent with this codebase's existing test style (`tests/test_menu.lua`, `tests/test_main_menu.lua`, `tests/test_statemachine.lua`).
- **`tests/test_screen_manager.lua`** replaces `tests/test_statemachine.lua`, carrying forward its existing cases (switch/exit/enter ordering, dispatch-to-active-only, no-op-when-method-missing, forwarding unknown calls) and adding stack-specific cases: `promote` pauses the old top and enters the new one without exiting the old one; `dismiss` exits the top and resumes the new top; `replace` exits every screen on the stack (in top-to-bottom order) and leaves a single-entry stack; `draw` skips non-opaque screens above an opaque one but still draws everything from the topmost opaque screen upward (e.g. `[opaque, opaque, overlay]` draws the last two, not all three); update/keypressed dispatch only ever reaches the top screen, never anything paused beneath it.
- **Per-screen tests** (`tests/test_game_screen.lua`, `tests/test_main_menu_screen.lua`, `tests/test_options_screen.lua`, `tests/test_pause_screen.lua`, `tests/test_win_screen.lua`, `tests/test_game_over_screen.lua`) replace `tests/test_gamestate.lua`, each driving the screen directly against a stub host object (a fake exposing `promote`/`replace`/`dismiss`/`quit` as spies) and asserting which host method fired with which argument for a given key/tap input — mirrors how `tests/test_main_menu.lua` already stubs callbacks to verify wiring rather than re-deriving pixel bounds.
- `tests/test_menu.lua`'s existing tree/hit-test tests for `menu.lua`'s view-layer functions are unaffected — this PRD doesn't change `menu.lua`'s public API, only who calls it.
- This is primarily a structural refactor (same spirit as PRD 008): the bar is "every existing test that exercised a behavior still passes once rewritten against the new module," not new behavior.

## Out of Scope

- Any change to `menu.lua`'s `lib/ui` tree-building or visuals (PRD 019's output) — reused as-is.
- The two open triage PRDs (`touch-usability-fixes.md`, `mouse-tap-swipe-parity.md`) — this refactor changes *who* owns input dispatch (screens instead of `main.lua`), not the actual touch-handling bugs/behavior they describe. They should be re-scoped against the new screen modules once this refactor lands, not bundled into it.
- New screens beyond the six listed (e.g. a settings sub-page, confirmation dialogs) — this PRD only relocates existing screens onto the new mechanism.
- Persistence/config changes — `settings.lua`/`config.lua` are untouched.

## Further Notes

This PRD was registered without a grilling session, at the user's explicit request, as a placeholder for a future `/grill-me` pass. Several decisions above are this author's best synthesis of the existing codebase, not confirmed user decisions, and should be treated as the starting point for grilling rather than settled:

- **Pause is included as a sixth screen even though the user's list only named game/main-menu/options/win/lose.** It has no other home in a stack model (it must be *something* promoted on top of Game), so folding it in seemed like the only coherent option — but this should be explicitly confirmed, not assumed.
- **`dismiss()` on a single-screen stack** — error loudly, or silently no-op? Should never happen if every screen transition is wired correctly, but the failure mode is worth deciding deliberately.
- **Quit**: whether screens call `love.event.quit()` directly or go through a `host:quit()` indirection (the PRD leans toward the latter for consistency with `promote`/`replace`/`dismiss` all being host-mediated, but it's a thin enough wrapper that either is defensible).
- **`game/screens/` as a new subdirectory** vs. flat files in `game/` (today's convention for everything except `lib/ui` and `renderer/`) — flagged as a real choice, not a foregone conclusion.
- Whether `ScreenManager` should guard against promoting/replacing while mid-transition (e.g. a screen's `enter()` itself synchronously triggering another promote) — not addressed above; worth a deliberate answer rather than discovering it as a bug.
