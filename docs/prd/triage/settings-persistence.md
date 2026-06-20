---
title: "Settings Persistence"
description: "All settings reset to defaults on every launch. Players must reconfigure each session."
status: needs-triage
---

# Settings Persistence

## Problem Statement

After PRD 011, all settings (tileset, animation toggles) reset to defaults on every launch. Players must reconfigure each session.

## Solution

`settings.lua` saves its state to disk via `love.filesystem` whenever a value changes, and loads it on startup.

## User Stories

1. As a player, I want my tileset choice to be remembered between sessions, so that I don't have to re-select it every time.
2. As a player, I want my animation and effect toggle preferences to persist, so that my setup is ready immediately on launch.

## Implementation Decisions

- **`settings.lua`** — `load()` reads a file (e.g. `settings.lua` in the Love2D save directory) via `love.filesystem.read()`, deserializes it with `load()` (sandboxed), and populates the in-memory table. `save()` serializes the table to a Lua literal string and writes it via `love.filesystem.write()`. `set(key, value)` updates the in-memory value and calls `save()` immediately.
- `main.lua` calls `settings.load()` before any other module initializes.
- No new UI — persistence is transparent to the player.
- If the settings file is missing or corrupt, defaults are used silently and the file is rewritten on the next `set()` call.

## Testing Decisions

- Test that `save()` followed by a fresh `load()` (on a new `settings` instance) produces the same values.
- Test that a missing settings file causes `load()` to return without error and leave defaults intact.
- Test that a corrupt file (invalid Lua) causes `load()` to fall back to defaults without crashing.

Note: tests stub `love.filesystem` with an in-memory store — no actual file I/O required.

## Out of Scope

- Game state persistence (board, score).
- Settings migration across versions.
- Multiple profiles.

## Further Notes

The settings file is stored in the Love2D identity save directory (`love.filesystem.getSaveDirectory()`), not next to the game source, so it survives game updates.
