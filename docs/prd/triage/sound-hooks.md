---
title: "Sound Hooks"
description: "There is no audio infrastructure. Adding sound effects later will require touching multiple call sites scattered across game logic and state modules."
status: needs-triage
---

# Sound Hooks

## Problem Statement

There is no audio infrastructure. Adding sound effects later will require touching multiple call sites scattered across game logic and state modules.

## Solution

Introduce a `sound.lua` module with named event hooks (`move`, `merge`, `win`, `game_over`). If a matching audio file exists in a `sounds/` folder, it plays; otherwise the call is a no-op. No audio files are shipped with this PRD.

## User Stories

1. As a developer, I want a single `sound.play(event)` call site per game event, so that wiring real audio later requires no structural changes.
2. As a player (future), I want sounds to play automatically if audio files are placed in the `sounds/` folder, so that customising audio requires no code changes.

## Implementation Decisions

- **`sound.lua`** — `load()` scans `sounds/` for files named `move.wav`, `merge.wav`, `win.wav`, `game_over.wav`. Each found file is loaded as a `love.audio.Source` (static type). `play(event)` calls `source:play()` if the source exists, otherwise does nothing.
- Call sites:
  - `gamestate.lua` (playing state) calls `sound.play("move")` after a successful move.
  - `gamestate.lua` (playing state) calls `sound.play("merge")` when the move result contains at least one merge.
  - `gamestate.lua` transitions call `sound.play("win")` and `sound.play("game_over")`.
- `main.lua` calls `sound.load()` on startup.

## Testing Decisions

- Test that `play(event)` with no loaded sources does not error.
- Test that `play("unknown_event")` does not error.
- No test for actual audio playback — that requires a Love2D runtime.

## Out of Scope

- Volume control.
- Background music.
- Sound toggle in Options (can be added to PRD 011 toggles in a follow-up).

## Further Notes

Using `wav` format ensures compatibility across platforms without requiring extra Love2D audio codec configuration.
