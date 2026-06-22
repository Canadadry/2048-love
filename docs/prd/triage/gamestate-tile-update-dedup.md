---
title: "Dedupe Tile-Animation Update Loop in gamestate.lua"
description: "Base:update and PlayingState:update independently reimplement the same 'tick tiles, check any_alive, clear when done' loop; collapse them into one shared helper."
status: needs-triage
---

## Problem Statement

`gamestate.lua` has two copies of the same tile-animation bookkeeping: `Base:update` (used by every non-Playing state) and `PlayingState:update` both tick every entry in `ctx.tiles`, scan for any tile that isn't `is_done()`, and clear `ctx.tiles` to `{}` once none are. `PlayingState:update` adds its own pause-pending/queue-draining behavior around the same loop instead of reusing the shared one. As a developer, touching tile-animation semantics today means remembering to change both copies in lockstep — a future "every existing test still passes" refactor (e.g. the planned screen-stack rework) inherits this duplication instead of cleaning it up.

## Solution

Extract the "tick tiles, report whether any are still alive, clear `ctx.tiles` if not" logic into one private helper in `gamestate.lua`. `Base:update` calls it directly. `PlayingState:update` calls the same helper and only adds the pause-pending/queue logic that's unique to it. Behavior is unchanged — this is a pure internal dedup, not a feature change.

## User Stories

1. As a developer, I want tile-animation ticking to exist in exactly one place in `gamestate.lua`, so a future change to animation-completion semantics (e.g. adjusting how "done" is determined) only requires one edit.
2. As a developer, I want `PlayingState:update` to read as "advance tiles; if just finished and a pause was requested, switch to paused; otherwise drain the next queued move," not as a second copy of the tile-ticking loop.
3. As a developer maintaining the planned screen-stack refactor, I want this dedup landed first (or folded in cleanly), so the new `GameScreen` module inherits one tile-update implementation, not two to merge.
4. As a player, I want zero observable behavior change — animations, pause-pending deferral, and move-queue draining all behave exactly as they do today.

## Implementation Decisions

- Add a private helper in `gamestate.lua`, e.g. `local function advance_tiles(ctx) -> any_alive`, that performs exactly the loop currently duplicated in `Base:update` (lines tracking `ctx.tiles`, checking `t:is_done()`, clearing `ctx.tiles = {}` when none remain) and returns whether any tile is still animating before the clear.
- `Base:update` becomes: tick particles, then call the helper, replacing its own inline loop.
- `PlayingState:update` becomes: if `#ctx.tiles == 0`, run its existing pause-pending/queue-drain branch unchanged. Otherwise, call the same helper; if it reports no tile still alive (i.e. animation just finished), run the existing pause-pending check that today lives after its own loop.
- No change to `tile.lua`'s public interface (`t:update(dt)`, `t:is_done()`) — the helper only orchestrates calls already being made today, it doesn't change tile semantics.
- No change to `Base`'s or `PlayingState`'s public methods (`update(dt)` signature and effect are unchanged) — this is purely an internal restructuring of `gamestate.lua`.

## Testing Decisions

- This is a pure refactor: the bar is "every existing test in `tests/test_gamestate.lua` still passes unchanged," consistent with this codebase's existing refactor PRDs (e.g. PRD 008).
- Add a focused unit test (or extend an existing one in `tests/test_gamestate.lua`) asserting that `PlayingState:update`, when a pause was requested mid-animation, still defers the pause exactly until the in-flight tiles finish — this is the one behavior most at risk of being subtly altered by the merge, so it should be pinned down explicitly rather than relying on incidental coverage.
- No new test file needed; this stays within `tests/test_gamestate.lua`'s existing scope, following this codebase's pattern of one test file per source module.

## Out of Scope

- Any change to `tile.lua`'s animation/easing logic itself.
- The pause-pending mechanism's behavior or semantics — only its code location/structure changes.
- The broader screen-stack refactor (`docs/prd/triage/screen-stack-refactor.md`) — this PRD is a small, independent cleanup that refactor can build on top of, not a prerequisite blocking it.

## Further Notes

This was identified during a `/guideline`-driven technical-debt survey of the codebase (not a user-reported bug). Low risk, small diff — a good candidate to land before or independently of the larger screen-stack refactor.
