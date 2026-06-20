---
title: "Animation & Effect Toggles"
description: "Slide animation and merge pop/scale effect are always on. Players on low-end hardware or with a preference for instant feedback cannot disable them."
status: needs-triage
---

# Animation & Effect Toggles

## Problem Statement

Slide animation and merge pop/scale effect are always on. Players on low-end hardware or with a preference for instant feedback cannot disable them.

## Solution

Add two toggles to the Options screen: one for slide animation, one for the merge pop/scale effect. Each is an on/off toggle navigated with arrow keys and flipped with Enter or Left/Right.

## User Stories

1. As a player, I want to toggle slide animation on or off from the Options screen, so that I can prefer instant moves if desired.
2. As a player, I want to toggle the merge pop/scale effect on or off from the Options screen, so that I can reduce visual noise.
3. As a player, I want the toggles to take effect immediately, so that I can see the result without restarting.

## Implementation Decisions

- **`settings.lua`** — introduced here as a simple in-memory table with `animations_enabled` (default `true`) and `effects_enabled` (default `true`). Persistence is added in PRD 012; for now it resets on launch.
- **`options.lua`** gains two toggle list items below the tileset picker. Left/Right or Enter flips the boolean in `settings`. The displayed label reflects the current value ("Animations: ON / OFF").
- **`tile.lua`** — `update(dt)` checks `settings.animations_enabled`; when false, tiles snap to target immediately (timer set to `ANIM_DURATION`). Checks `settings.effects_enabled`; when false, `merge_timer` is never set.
- **`config.lua`** default values for both flags are removed — `settings.lua` owns defaults.

## Testing Decisions

- Test that when `animations_enabled = false`, tile positions snap to target on the first `update()` call regardless of elapsed time.
- Test that when `effects_enabled = false`, `tile.scale` remains `1.0` after a merge event.

## Out of Scope

- Persistence (PRD 012).
- Fine-grained animation speed control.

## Further Notes

`settings.lua` is intentionally introduced as a dumb in-memory table here so PRD 012 can add I/O underneath the same interface without changing any caller.
