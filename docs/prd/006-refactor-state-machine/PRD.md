Status: needs-triage

# PRD 006 — Refactor: State Machine

## Problem Statement

After PRD 005, `gamestate.lua` handles `menu`, `playing`, `you_win`, and `game_over` through ad-hoc conditionals. Adding the Options screen (PRD 009) and more screens beyond that will make this unmaintainable.

## Solution

Refactor `gamestate.lua` into a proper state machine. Each state is a module with a defined lifecycle interface. The state machine owns transitions and dispatches Love2D callbacks to the active state.

## User Stories

1. As a developer, I want each game state to implement a consistent interface, so that adding a new screen never requires touching the state machine core.
2. As a developer, I want enter/exit hooks per state, so that setup and teardown are co-located with the state logic.

## Implementation Decisions

- **`statemachine.lua`** — new module. Holds a stack or single-slot active state. Exposes `switch(state)` which calls `active.exit()` then `next.enter()`, then sets `active = next`. Dispatches `update(dt)`, `draw()`, `keypressed(key)` to `active`.
- Each state (menu, playing, you_win, game_over) becomes a table with `enter()`, `exit()`, `update(dt)`, `draw()`, `keypressed(key)`. Missing methods are no-ops.
- **`gamestate.lua`** is retired; `main.lua` now owns the state machine instance and delegates callbacks to it.
- No behavioral changes — this is a pure structural refactor. All existing transitions and logic move into their respective state tables.

## Testing Decisions

- Test `statemachine.lua` in isolation: `switch()` calls `exit()` on the old state and `enter()` on the new one in the right order.
- Test that dispatching `keypressed` on the machine calls the active state's handler and not the old state's.

## Out of Scope

- State stack / push-pop (not needed for this game's screen count).
- Any new screens or behavior.

## Further Notes

After this refactor, adding PRD 009's Options screen is a single new state table with no changes to the machine itself.
