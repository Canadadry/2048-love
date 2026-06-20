Status: needs-triage

# PRD 009 — Options Screen Shell

## Problem Statement

There is no way to access settings from within the game. Future PRDs (010, 011) need a screen to host controls, but that screen doesn't exist yet.

## Solution

Add an Options screen reachable from the main menu. It renders a placeholder list, handles Escape to go back, and is wired into the state machine. Individual controls are added in subsequent PRDs.

## User Stories

1. As a player, I want an Options entry in the main menu, so that I can reach settings without editing config files.
2. As a player, I want to press Escape from the Options screen to return to the main menu, so that navigation is consistent.
3. As a developer, I want the Options screen to be a proper state machine state, so that adding controls in PRD 010 and 011 requires no structural changes.

## Implementation Decisions

- **`options.lua`** — new state module implementing the state machine interface from PRD 006 (`enter`, `exit`, `update`, `draw`, `keypressed`). `draw()` renders a titled screen with a placeholder "No options yet" message. `keypressed("escape")` calls `statemachine.switch(menu_state)`.
- **`menu.lua`** gains an "Options" item between "New Game" and "Quit". Selecting it calls `statemachine.switch(options_state)`.
- No new data, no new config keys.

## Testing Decisions

- No unit tests — this PRD adds only navigation wiring and an empty screen.

## Out of Scope

- Any actual option controls (PRD 010, 011).
- Back button rendered on screen (Escape-only navigation is sufficient).

## Further Notes

Options state calls `statemachine.switch(menu_state)` on Escape — it does not push/pop, since the state machine in PRD 006 is a single-slot switcher.
