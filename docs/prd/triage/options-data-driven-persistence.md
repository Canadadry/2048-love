---
title: "Data-Driven Options Row Persistence"
description: "options.lua's persist_focused_row is a hardcoded if/elseif per row number; attach the config/settings key to each row definition instead so persistence is a generic loop."
status: needs-triage
---

## Problem Statement

`options.lua` defines its rows as a list (Win Tile, Theme, Animations, Effects, Back) when the screen is entered, then separately hardcodes, in `persist_focused_row`, which `config` field and which `settings.set` key corresponds to each row *by row number* (`WIN_TILE_ROW`, `THEME_ROW`, `ANIMATIONS_ROW`, `EFFECTS_ROW` constants plus an `else` for Effects). The row list and the persistence branch are two separate places that both encode "row N maps to config field X / settings key Y," kept in sync only by convention. As a developer adding a sixth option row, today's path requires adding both a new row table entry *and* a new `elseif` branch in `persist_focused_row` — easy to add one and forget the other, since nothing forces them to agree.

## Solution

Attach the config field and settings key directly to each row's definition (the same table already passed to `optionsmodel.new`), and rewrite `persist_focused_row` as a generic loop over the focused row's own metadata instead of a row-number switch. Adding a new option row becomes "add one row table entry" — there's no second place to remember to update.

## User Stories

1. As a developer adding a new option (e.g. a future "Sound" toggle), I want to add it as a single row entry carrying its own config field and settings key, so persistence wiring can't be forgotten in a separate branch.
2. As a developer reading `options.lua`, I want the row list to be the single source of truth for "what this row controls," so I don't have to cross-reference row-number constants against a separate `if/elseif` chain to understand what Left/Right on a given row actually persists.
3. As a player, I want every existing option (Win Tile, Theme, Animations, Effects) to keep persisting to disk exactly as it does today, with no observable change in behavior.
4. As a developer, I want the Back row to remain a no-op for persistence (it carries no value to save) without needing a special-cased early return, so the generic loop naturally skips rows with no config/settings key.

## Implementation Decisions

- Each row table passed to `optionsmodel.new` in `OptionsState:enter()` gains two optional fields: `config_key` (the field name on the `config` module, e.g. `"WIN_TILE"`) and `setting_key` (the key passed to `settings.set`, e.g. `"win_tile"`). The Back row omits both, exactly as it already omits `value_index` today.
- `optionsmodel.lua` requires no changes: it already treats row tables as opaque beyond `.values`/`.value_index`, so passing through extra fields is already supported by its existing interface. This keeps the model itself free of persistence concerns — it stays a pure focus/value-cycling state machine, and `options.lua` (the only piece that knows about `config`/`settings`) remains the only thing that reads the new fields.
- `persist_focused_row(self)` is rewritten to: look up the focused row's definition (not just its value) from the same row list `enter()` built; if it has no `config_key`, return (covers Back); otherwise set `config[row.config_key] = value` and `settings.set(row.setting_key, value)`. This requires `OptionsState` to keep a reference to the row definitions (or expose them via the model) so `persist_focused_row` can look up a row's `config_key`/`setting_key` by index, alongside the value it already gets via `self._model:row_value(i)`.
- The `WIN_TILE_ROW`/`THEME_ROW`/`ANIMATIONS_ROW`/`EFFECTS_ROW`/`BACK_ROW` numeric constants can be retired once nothing branches on them by number — `optionsmodel.lua`'s `focused_row()` returning Back's row index is still needed for the `keypressed`/`tap_row` Back-handling, so at minimum `BACK_ROW`'s role there (or an equivalent "is this the Back row" check) stays, but the four data-row constants used only inside `persist_focused_row` go away.

## Testing Decisions

- Behavior-level tests only, consistent with `tests/test_options.lua`'s existing style (which already drives `gamestate`'s Options state and asserts on `config`/`settings` outcomes, not on which internal branch ran).
- `tests/test_options.lua` keeps its existing assertions that cycling Win Tile/Theme/Animations/Effects persists the right `config` field and the right `settings.set` key — these tests validate the new generic loop for free since they assert observable outcomes.
- Add one new case: confirm that cycling Left/Right while focused on the Back row does not call `settings.set` at all (today this is implicit/untested via the `if row == BACK_ROW then return end` branch; the generic-loop version deserves an explicit regression test since "rows without a config_key are silently skipped" is now the only thing preventing a future row-list bug from crashing or persisting garbage).
- `tests/test_optionsmodel.lua` needs no changes — `optionsmodel.lua`'s interface and behavior are untouched by this PRD.

## Out of Scope

- Adding any new option row (e.g. Sound) — this PRD only makes the existing four rows' persistence data-driven; it doesn't add new options.
- Any change to `optionsmodel.lua`'s focus/value-cycling logic (`up`/`down`/`left`/`right`/`focus_row`/`row_value`).
- Any change to how rows are rendered (`menu.lua`'s `build_options_tree`) — only how `options.lua` persists a row's value once changed.

## Further Notes

This was identified during a `/guideline`-driven technical-debt survey, not a user-reported bug. Lowest priority of the three triaged refactors in this batch — the current code is correct today, this only reduces the chance of a future row addition forgetting to wire persistence.
