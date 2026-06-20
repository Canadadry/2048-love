---
title: "Game States: Win & Game Over Overlays"
description: "After PRD 001, the game freezes silently when a player wins or runs out of moves. There is no feedback and no way to restart without quitting."
status: needs-triage
---

# Game States: Win & Game Over Overlays

## Problem Statement

After PRD 001, the game freezes silently when a player wins or runs out of moves. There is no feedback and no way to restart without quitting.

## Solution

Add a semi-transparent overlay for each terminal state. The You Win overlay offers Continue (keep playing, overlay never returns) and Restart. The Game Over overlay offers Restart only.

## User Stories

1. As a player, I want a "You Win!" overlay to appear when I create a 2048 tile, so that my achievement is acknowledged.
2. As a player, I want a Continue option on the You Win overlay, so that I can keep playing past 2048 without starting over.
3. As a player, I want a Restart option on both overlays, so that I can start a new game immediately.
4. As a player, I want the You Win overlay to disappear permanently after I choose Continue, so that it does not reappear if I reach 4096 or beyond.
5. As a player, I want a "Game Over" overlay when no moves remain, so that I know the game has ended.
6. As a player, I want to navigate overlay options with arrow keys and confirm with Enter, so that I can use the same input method as the game itself.

## Implementation Decisions

- **`gamestate.lua`** gains two new states: `you_win` and `game_over`.
- Transition to `you_win` is one-way per session — a flag (`win_seen`) in the playing state prevents re-triggering.
- `you_win` state holds a cursor (0 = Continue, 1 = Restart). Up/Down moves cursor. Enter confirms.
- `game_over` state has a single action (Restart). Enter or any arrow key confirms.
- **`renderer.lua`** gains two overlay draw functions — a dimmed full-screen rectangle plus centered text and option labels. Highlighted option is drawn in a distinct color.
- No new modules introduced.

## Testing Decisions

- Test that `gamestate` transitions to `you_win` exactly once per session even if multiple 2048+ merges occur.
- Test that choosing Continue from `you_win` returns to `playing` state with the existing board intact.
- Test that choosing Restart from either overlay resets the board and score to initial state.

## Out of Scope

- Animations on overlay appearance (considered cosmetic, deferred).
- Keyboard shortcut to restart without navigating the overlay.
- Main menu (PRD 005).

## Further Notes

The `win_seen` flag lives on the playing-state table, not on the grid, so a Restart correctly resets it.
