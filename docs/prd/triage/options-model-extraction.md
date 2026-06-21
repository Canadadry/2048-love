---
title: "Options Row-Focus Model Extraction"
description: "Landing the row-focus redesign of the Options screen as one big-bang change is risky; this extracts the row/focus/value-cycling logic into a standalone, unwired, fully-tested pure module first."
status: needs-triage
---

# Options Row-Focus Model Extraction

## Problem Statement

`docs/prd/triage/options-row-focus-navigation.md` describes a redesign of the Options screen: Win Tile and Theme become two rows sharing a single focus, moved by Up/Down, with Left/Right always editing whichever row has focus. Implementing that redesign and rewiring `options.lua`/`menu.lua`/`main.lua` in one shot bundles a new, well-isolated piece of logic together with changes to the live game loop, the rendering code, and the existing test suite — all in a single change. That makes the change harder to review and riskier to land than necessary, since a mistake anywhere in the bundle affects the live Options screen immediately.

## Solution

Build the row-focus model as its own pure module — no Love2D dependency, no `config` dependency, no wiring into the live game. It gets its own unit tests. The live Options screen (`options.lua`, `menu.lua`, `main.lua`) and its existing tests (`tests/test_options.lua`) are not touched at all in this PRD — Win Tile keeps direct-toggling, Theme keeps its cursor-and-Enter behavior, exactly as today. This PRD only adds new, currently-unused code; wiring it in and changing the screen's live behavior remains the scope of `options-row-focus-navigation.md`.

## User Stories

1. As a developer, I want the row-focus and value-cycling logic in a standalone module with no Love2D dependency, so that I can unit test it without stubbing the game loop or `love.filesystem`.
2. As a developer, I want this module built and tested before any wiring changes happen, so that the eventual cutover to the new Options screen behavior is a small, low-risk change instead of a single large rewrite.
3. As a developer, I want the existing Options screen behavior to be completely unaffected by this PRD, so that this refactor can land safely with no risk of regressing the live game.
4. As a developer, I want the model's row list to be declarative (label + ordered values), so that defining the eventual Win Tile and Theme rows is straightforward when the cutover happens.
5. As a developer, I want focus movement (Up/Down) to wrap at both ends of the row list, so that the model matches the navigation behavior already decided in the row-focus navigation PRD.
6. As a developer, I want value cycling (Left/Right) to only ever affect the currently focused row, so that the model enforces the single-editable-row invariant at its core, not just by convention in the caller.
7. As a developer, I want value cycling to wrap at both ends of a row's value list, so that cycling through any number of values (2 for Win Tile, N for Theme) behaves consistently.
8. As a developer, I want focus changes to never alter any row's current value, and value changes to never alter focus, so that the two axes of interaction are fully independent and easy to reason about.

## Implementation Decisions

- **New pure module (`optionsmodel`)** — no dependency on Love2D, `config`, or any other game module. Constructed from a declarative list of rows, where each row has a label, an ordered list of possible values, and a starting value-index.
  - `up()` / `down()` — move the focus index between rows, wrapping at both ends.
  - `left()` / `right()` — move the value-index of the currently focused row only, wrapping at both ends of that row's value list. Application is immediate — there is no separate "confirm" step, matching the apply-immediately decision already made in `options-row-focus-navigation.md`.
  - `focused_row()` — returns the index of the row currently in focus.
  - `row_value(i)` — returns the current value of row `i`.
  - This is a pure data-in/data-out module: it owns no global state and has no side effects, making it independently testable.
- No other module is built or modified in this PRD. `options.lua`, `menu.lua`, and `main.lua` are explicitly out of scope here — they continue to use their current, separate Win Tile/Theme logic untouched.
- The eventual rows the model will hold (Win Tile, Theme) are defined by the consuming PRD (`options-row-focus-navigation.md`), not by this one — this PRD's module is generic and doesn't hardcode Options-screen-specific row content.

## Testing Decisions

- Tests target only externally observable behavior of the new module (focus position, row values, wrap behavior) — no internal table-shape assertions.
- New test file for the `optionsmodel` module, added to the project's test-suite runner alongside the other suites (no Love2D stubs required, since the module has no Love2D dependency):
  - `up()`/`down()` move focus between rows and wrap at both ends of the row list.
  - `left()`/`right()` change only the focused row's value-index; every other row's value is unaffected.
  - `left()`/`right()` wrap at both ends of the focused row's value list.
  - Changing focus (`up()`/`down()`) never changes any row's current value.
  - Changing a row's value (`left()`/`right()`) never changes which row has focus.
- No changes to `tests/test_options.lua` — it continues to test the live, unchanged `OptionsState` behavior.
- Prior art: this module follows the same "pure logic module + dedicated unit test file" pattern already used in the codebase for non-Love2D-dependent logic (e.g. the tile/animation timing helpers and the tileset name-listing logic each have their own focused unit tests separate from the integration-style state tests).

## Out of Scope

- Wiring `optionsmodel` into `options.lua`, `menu.lua`, or `main.lua` — that is the scope of `options-row-focus-navigation.md`.
- Any change to the live Options screen's behavior, rendering, or hint text.
- Any change to `tests/test_options.lua`.
- Defining the actual Win Tile/Theme row configuration used by the live game — this PRD's module is generic and row-content-agnostic.

## Further Notes

This PRD exists purely to de-risk `options-row-focus-navigation.md` by splitting it into a safe, no-behavior-change preparation step (this PRD) and a smaller follow-up cutover step (the existing PRD). Once this module is built and tested, `options-row-focus-navigation.md`'s implementation work is reduced to configuring two rows and rewiring `options.lua`/`menu.lua`/`main.lua` to delegate to it.
