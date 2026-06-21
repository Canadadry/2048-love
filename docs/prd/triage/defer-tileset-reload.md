---
title: "Defer Tileset Reload to New Game"
description: "The tileset PNG (decode + quad rebuild) reloads on app open and on every Options-screen interaction, even when the theme didn't change, causing visible lag; it should only reload when a game actually starts, and only if the requested tileset isn't already loaded."
status: needs-triage
---

# Defer Tileset Reload to New Game

## Problem Statement

Loading a tileset (`tileset.load()` decoding the PNG, then `tile_draw.lua` rebuilding every value's animation quads) is expensive, and today it happens far more often than it needs to:

1. **On app open.** `main.lua`'s `love.load()` calls `renderer.load()`, which unconditionally calls `renderer.set_tileset(config.TILESET)` before the player has even reached a screen that shows a tile — the first screen is always the Main Menu, which doesn't render the board at all.
2. **On every Options-screen interaction, regardless of which row changed.** `main.lua`'s `love.keypressed` (when `state:in_options()` and the key is Left/Right) and `handle_tap`'s `state:in_options()` branch both call `renderer.set_tileset(config.TILESET)` unconditionally — including when the row being cycled is **Win Tile**, **Animations**, or **Effects**, none of which touch the tileset at all, and even on a tap that merely focuses a row without changing its value. Every one of those triggers a full PNG reload + quad rebuild, which is the visible lag the user is reporting while navigating Options.

The Options screen never shows the board (PRD 019 made it a full-window overlay), so none of this eager reloading has any visible benefit before the player actually returns to play — it's pure wasted, laggy work.

## Solution

Make tileset loading lazy and idempotent:

- **Idempotent**: re-requesting the tileset that's already loaded does no decode/rebuild work at all — it's a cheap no-op.
- **Lazy**: the request to load/swap the tileset only happens at the point a game's board is actually about to be shown (a fresh New Game, a Restart, or a Continue/Resume back into an already-running game) — never from app startup and never from Options-screen input handling.

Combined, this means: changing Theme in Options updates `config.TILESET` immediately (as it does today, for persistence), but the actual PNG swap is deferred until the player is back on the board with a game running, and if they didn't end up changing the theme (or already have the right one loaded from a previous game), nothing reloads at all.

## User Stories

1. As a player, opening the app shows the Main Menu immediately, without waiting on a tileset PNG decode I won't see until I start playing.
2. As a player, navigating the Options screen (cycling Win Tile, Theme, Animations, or Effects, or just moving focus between rows) is instant — no stutter from an unrelated asset reload firing on every keypress or tap.
3. As a player, when I change Theme in Options and then start/resume a game, the new theme is applied to the board — the deferral doesn't lose or delay my choice past the point I actually need it.
4. As a player, restarting or continuing a game without having changed the theme doesn't re-decode the same PNG over again — it's instant, same as today's first load of a session.
5. As a developer, I want the "should this tileset actually be (re)loaded" decision to be a small, pure, isolated piece of logic, so it can be unit-tested without needing a real `love.graphics` context (which the headless `make test-game` runner doesn't provide).
6. As a developer, I want the public `renderer`/`tile_draw` API to stay simple (still just "tell me the desired tileset name") — callers should never need to know or care whether a reload actually happened.
7. As a developer, I want `gamestate.lua` to remain free of any dependency on the `renderer` module (today's clean logic/view separation — `gamestate.lua` never `require`s `renderer`), so this fix should not introduce that coupling just to find a "new game started" hook.

## Implementation Decisions

- **`renderer/tile_draw.lua` becomes idempotent.** It already holds the only piece of state involved (`ts_data`, set by `M.set_tileset`). It additionally remembers the name it last (successfully or unsuccessfully) loaded. `M.set_tileset(name)` becomes a guarded call: if `name` equals the remembered name, it returns immediately and does no `tileset.load()` / `love.graphics.newImage` / `love.graphics.newQuad` work. Only on an actual name change does it do the real load and quad rebuild (today's full body of `M.set_tileset`).
  - The comparison itself is pulled out into a small pure helper (no `love.*` calls), e.g. `M.needs_reload(requested_name, loaded_name)`, so the "should I do the expensive thing" decision is unit-testable in isolation from the actual `love.graphics` calls, which the project's headless Lua test runner (`make test-game`) cannot exercise.
  - The empty-string theme (`""`, "None (classic)" — see `config.lua`'s default `M.TILESET = ""`) is a valid, distinct "loaded" state from "nothing requested yet" — the initial remembered name must use a sentinel that isn't itself a legal theme name, so the very first call (including a first call requesting `""`) is never mistaken for "already loaded."
- **Call site moves out of input handling, into the one place that actually draws the board.** `main.lua`'s `love.draw()` already has a single branch that renders gameplay (`renderer.draw(...)`, covering Playing/Paused/Win/Game Over — the only states that ever show tiles). `renderer.set_tileset(config.TILESET)` is called once per frame from that branch, immediately before `renderer.draw(...)`. Because the call is now idempotent, this costs nothing once the right tileset is already loaded — it naturally satisfies "only reload if it's not currently loaded" without any extra bookkeeping in `main.lua` or `gamestate.lua`.
  - The two existing call sites in `love.keypressed` (Options Left/Right) and `handle_tap` (Options tap branch) are deleted outright — they're no longer needed and were the actual source of the lag.
  - The eager call in `love.load()` (via `renderer.load()`) is removed — the first real load now happens the first time gameplay is drawn (i.e. once the player presses New Game from the Main Menu), not at app startup.
- **This keeps `gamestate.lua` render-agnostic.** The fix lives entirely in `main.lua` (which already talks to both `gamestate` and `renderer` today) and `renderer/tile_draw.lua`. No new `require("renderer")` inside `gamestate.lua`, and no new signal/flag has to be invented on the state machine side.
- **`config.TILESET` itself is unaffected** — Options screen keeps updating it (and persisting via `settings.lua`) the instant the player changes the Theme row, exactly as today. Only the renderer-side PNG swap is deferred; the model/config-side write is not.

## Testing Decisions

- The valuable, isolatable behavior here is the reload-or-skip decision, not the actual GPU/asset calls (which require a real LÖVE runtime and aren't covered by this project's headless suite, consistent with `tests/test_renderer_tile_draw.lua` today only testing `tile_color`, not `set_tileset`, for the same reason).
- **`tests/test_renderer_tile_draw.lua`** gains cases for the new pure helper: same name twice → no reload needed; different name → reload needed; first-ever call (sentinel "not loaded yet" state) → reload needed even when the requested name is `""`.
- No new test attempts to assert that `love.graphics.newImage`/`newQuad` were or weren't actually called — that's exactly the kind of implementation detail (vs. observable behavior) this codebase's test style avoids; it's covered by manual verification (`make run`, changing Theme in Options, confirming no stutter, confirming the new theme shows up once a game is running).
- No changes needed to `tests/test_options_screen` / `tests/test_gamestate.lua`-equivalent suites — `config.TILESET` mutation on Theme change is unaffected and already covered.

## Out of Scope

- Any change to how themes are authored/built (`tools/tileset-builder`, `tools/theme-builder`) — untouched.
- Any change to what Options persists or how (`settings.lua`) — untouched.
- Pre-warming/caching more than one tileset at a time (e.g. background-loading the newly chosen theme while still in Options, so it's instant the moment a game starts) — today's fix only removes wasted reloads; pre-warming would be a deliberate enhancement, not bundled here.
- The Screen Stack Refactor PRD (`docs/prd/triage/screen-stack-refactor.md`) — if that lands first, the call site described here (the single gameplay-draw branch in `main.lua`) becomes the Game screen's own `draw()`; the idempotent `tile_draw.lua` fix underneath is unaffected either way and this PRD's logic should simply be ported to wherever gameplay ends up being drawn.

## Further Notes

This PRD was registered without a grilling session, at the user's explicit request. Open questions for that session:

- **Failed-load retry behavior is unaddressed.** If `tileset.load(name)` fails (missing/corrupt asset) and `ts_data` ends up `nil`, should the next request for that same `name` retry, or stay "remembered as loaded" and silently keep failing? Not specified above.
- **Call-site placement is a real design choice, not a foregone one.** This PRD proposes a per-frame idempotent call from `main.lua`'s gameplay draw branch (simplest, zero new coupling) as opposed to a one-shot hook on "new game actually started" inside `gamestate.lua` (would need a `require("renderer")` there, or a new signal `main.lua` polls — both add coupling the per-frame approach avoids). Worth confirming the per-frame approach is acceptable before implementation, since "once per frame" sounds more wasteful than it actually is here (a single string comparison) but reads oddly at first glance.
- **`renderer.load()`'s fate** — it currently does nothing but call `set_tileset`; once that call is removed from `love.load()`, decide whether `renderer.load()` is deleted entirely or kept as an empty/future hook.
