---
title: "Main Menu"
description: "The game launches directly into play with no way to quit gracefully or navigate to settings."
status: needs-triage
---

# Main Menu

## Problem Statement

The game launches directly into play with no way to quit gracefully or navigate to settings.

## Solution

A main menu is the initial screen. It offers New Game and Quit. Arrow keys navigate, Enter confirms.

## User Stories

1. As a player, I want to see a main menu when I launch the game, so that I have a clear starting point.
2. As a player, I want a New Game option that starts a fresh 2048 game, so that I can begin play.
3. As a player, I want a Quit option that exits the application, so that I can close the game from the keyboard.
4. As a player, I want to navigate menu items with Up/Down arrow keys, so that I use the same input method as in-game.
5. As a player, I want to confirm a menu item with Enter, so that the interaction is consistent with game overlays.

## Implementation Decisions

- **`menu.lua`** — new module. Owns cursor position and the ordered list of menu items. Exposes `draw()` and `keypressed(key)`. On "new_game" action, signals gamestate to transition to `playing`. On "quit", calls `love.event.quit()`.
- **`gamestate.lua`** gains a `menu` state. `menu` is the initial state on `love.load`.
- **`main.lua`** routes `love.keypressed` to the active state's handler.
- Menu is drawn centered in the window with the game title above the options.

## Testing Decisions

- No unit tests for menu rendering or navigation — purely visual/input flow with no branching data logic.

## Out of Scope

- Options menu entry (PRD 009).
- High score display on the menu screen.
- Animated menu transitions.

## Further Notes

The playing state reached via New Game starts with a clean board and score of 0, identical to the post-Restart path from PRD 002 overlays.
