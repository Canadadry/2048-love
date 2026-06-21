---
title: "Win Explosion Particle Effect"
description: "Reaching the win tile feels visually flat — the win screen just appears with no celebratory payoff."
status: needs-triage
---

# Win Explosion Particle Effect

## Problem Statement

When a player reaches the win tile, the win screen simply appears — overlay, title, two buttons. There's no celebratory visual payoff matching the significance of the moment, unlike the slide animation and merge pop effect that already give weight to ordinary moves.

## Solution

When the win screen appears, scatter 50-100 small colored squares at random across the screen, each given an initial random velocity so they appear to "explode," then fall under gravity and disappear individually after a couple of seconds. The effect is built as a small, self-contained particle engine so it can be reused for other moments later, even though this PRD only wires it into the win screen.

## User Stories

1. As a player, I want a burst of colorful squares to appear when I win, so that the moment feels celebratory.
2. As a player, I want the burst to look organic and chaotic rather than mechanical, so that it reads as an explosion rather than a scripted animation.
3. As a player, I want the particles to fall and disappear on their own, so that I'm not stuck waiting for them or distracted indefinitely.
4. As a player, I want the Continue and Restart buttons to stay fully visible and clickable while particles are falling, so that the effect doesn't get in the way of playing.
5. As a player, I want to be able to click Continue or Restart immediately without waiting for the burst to finish, so that the effect never blocks my next action.
6. As a player, I want the burst to look the same regardless of my window size, so that resizing the window doesn't break or skew the effect.
7. As a player who has turned off Effects in Options, I want the win burst to be suppressed too, so that one setting controls all of the game's optional visual flourishes.
8. As a player, I want the burst to only happen once per game (when I first reach the win tile), so that it doesn't replay every time I revisit the win screen in some unexpected way.
9. As a developer, I want the particle simulation logic to be unit-testable without the Love2D runtime, so that it follows the same testing pattern as the rest of the game's logic (grid, tile, gamestate).
10. As a developer, I want the particle engine's core data model to be generic enough to reuse for a future effect, so that the next visual flourish doesn't require rebuilding this from scratch (even though no second use case exists yet).

## Implementation Decisions

- **New module `game/particle.lua`** (pure Lua, no `love.*` calls, follows the `check.lua`-validated, metatable-based style of `tile.lua`'s `AnimTile`):
  - A `Particle` object holds: `x, y` (position, normalized 0.0-1.0 fractions of screen width/height — not pixels, so the simulation has no notion of window size and stays correct across resizes, mirroring how `tile.lua` works in grid row/col and lets the renderer convert to pixels), `vx, vy` (velocity in screen-fractions/second), `color` (one of the 16 PICO-8 palette entries), and a `_lifetime`/`_timer` pair (randomized per particle, ~1.5-2.5s).
  - `M.spawn(count)` creates `count` particles, each with: a random `(x, y)` anywhere in `[0,1] x [0,1]`; a random initial velocity vector (random angle, magnitude drawn from an "energetic burst" range so particles visibly scatter before gravity dominates); a random color from the PICO-8 palette; a random lifetime within the ~1.5-2.5s window. `count` itself should be randomized 50-100 by the caller (e.g. `M.spawn(math.random(50, 100))`), or `spawn` can accept an optional explicit count and default to that random range — implementer's call.
  - `Particle:update(dt)` integrates velocity into position and applies a constant downward gravity acceleration to `vy` each frame, then advances `_timer`.
  - `Particle:is_dead()` returns true once `_timer >= _lifetime`.
  - No fade/alpha tracking — death is a hard cutoff (the particle is simply removed from the list, not drawn with a fading alpha first).
  - This module is intentionally generic at the data-model level (position/velocity/gravity/lifetime/color, an `update`/`is_dead` pair) so a future caller could reuse it for a different effect, but it does not grow any configuration surface (shapes, emitter curves, etc.) beyond what the win burst needs — no speculative abstraction.

- **`config.lua`** gains the tunable constants for this effect, following the existing pattern (`ANIM_DURATION`, `MERGE_EFFECT_DURATION`):
  - `PARTICLE_COUNT_MIN = 50`, `PARTICLE_COUNT_MAX = 100`
  - `PARTICLE_SIZE = 5` (fixed pixel size, not scaled to window/tile size)
  - `PARTICLE_LIFETIME_MIN = 1.5`, `PARTICLE_LIFETIME_MAX = 2.5`
  - `PARTICLE_GRAVITY` and an initial velocity magnitude range tuned for a visibly energetic scatter (exact values are an implementation/tuning detail, expressed in screen-fractions/second² and /second respectively)
  - `PARTICLE_COLORS` — a table of the 16 PICO-8 base palette colors (as `{r,g,b}` triples, 0-1 range to match `TILE_COLORS`' convention)

- **`gamestate.lua`**:
  - `ctx` (from `make_ctx`) gains `win_particles = {}`.
  - `Base:win_particles()` accessor returns `self._ctx.win_particles`, mirroring `Base:anim_tiles()`.
  - `WinState:enter()` spawns the burst via `particle.spawn(...)` into `ctx.win_particles`, but only when `config.EFFECTS_ENABLED` is true (same gating style as the merge pop's `m.merged and config.EFFECTS_ENABLED` check) — when effects are off, `ctx.win_particles` stays empty and nothing renders.
  - Particle ticking happens once per frame regardless of `ctx.tiles` state: `Base:update(dt)` currently early-returns when `#ctx.tiles == 0`, which would skip particle updates during the win screen (no anim tiles are active there). The update path needs restructuring so that `ctx.win_particles` is updated and filtered (removing individually-dead particles) independently of the `ctx.tiles` early return.
  - `ctx.win_particles` is reset to `{}` in `WinState:continue_game()`, `WinState:restart()`, and the shared `do_restart()` helper, so no in-flight particles carry over into gameplay or a fresh game.

- **`menu.lua`**:
  - `M.draw_win(cursor, particles)` gains a second parameter. After drawing the dimmed overlay, title, and buttons (unchanged), it draws each particle last (in front of everything) as a `PARTICLE_SIZE x PARTICLE_SIZE` filled rectangle, converting each particle's normalized `(x, y)` to pixels via `love.graphics.getDimensions()` (full window, not `board_metrics()`, since particles scatter across the whole screen, not just the board area).
  - This keeps all win-screen visual logic (overlay, title, buttons, particles, z-order) inside `menu.lua`'s existing `draw_win()`, consistent with how that function already owns the entire win-screen presentation.

- **`renderer/init.lua`** / **`main.lua`**: the call site `menu.draw_win(cursor)` becomes `menu.draw_win(cursor, state:win_particles())`, matching how `anim_tiles()` is already threaded through similarly-shaped call sites.

## Testing Decisions

- Good tests here assert observable behavior (ranges, counts, state transitions), not exact RNG output or pixel-level rendering — this matches existing precedent (`tests/test_grid.lua`'s `spawn_tile` test asserts the spawned value is 2 or 4, not which cell or which value was rolled).
- **`tests/test_particle.lua`** (new): `spawn(n)` returns exactly `n` particles; each spawned particle's position is within `[0,1]` on both axes, color is one of the 16 palette entries, and lifetime is within the configured min/max window; `update(dt)` moves a particle and increases `vy` (gravity) over time; `is_dead()` is false before the lifetime elapses and true after; a particle's position integrates velocity correctly over a known `dt`.
- **`tests/test_gamestate.lua`** (extended): entering the win state with `EFFECTS_ENABLED = true` populates `win_particles()` with a count in the 50-100 range; entering with `EFFECTS_ENABLED = false` leaves it empty; `continue_game()` and `restart()` from the win state clear `win_particles()`; restarting from any other state also leaves `win_particles()` empty (regression coverage via the shared `do_restart()` path); particles individually disappear from `win_particles()` over repeated `update(dt)` calls as their lifetimes expire (not all at once), distinguishing this from the bulk-clear behavior of `anim_tiles()`.
- **`menu.lua`**'s particle drawing is not tested, consistent with `tile_draw.lua`'s untested scale-transform code (016-merge-effect.md) — visual-only code in this codebase isn't pixel-tested.
- No changes needed to `tests/test_tile.lua`, `tests/test_renderer_*`, or `tests/test_options.lua` — this feature doesn't touch animation timing, board rendering, or the Options screen.

## Out of Scope

- A new Options-screen toggle dedicated to this effect — it's gated by the existing `EFFECTS_ENABLED` toggle only.
- Reusing the particle engine for any other effect (game over, merge, menu transitions) — `particle.lua`'s data model is kept generic enough to allow it, but no second call site is built in this PRD.
- Fade-out/alpha animation on particle death.
- Scaling particle size to window/tile size — fixed 5x5 px regardless of resolution.
- Spawning particles continuously/in waves — this is a single burst per win, not a sustained emitter.
- Sound effects accompanying the burst.

## Further Notes

- The normalized-coordinate approach is the same architectural pattern already used for `AnimTile` (grid row/col converted to pixels at draw time via `board.cell_to_px`), extended here to raw screen fractions since particles aren't tied to board cells.
- `PARTICLE_GRAVITY` and the initial velocity magnitude range are left as tuning values for the implementer to set and adjust by feel (similar to how `MERGE_EFFECT_DURATION = 0.12` was picked without a separate design discussion) — the design intent is "energetic burst, gravity arcs it down within roughly the particle's lifetime," not a specific physics constant.
