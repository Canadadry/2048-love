---
title: "Unify the Options Screen's Back Row"
description: "The Options screen's Back control is a separately-styled button bolted on below the row list, and isn't part of the same Up/Down focus-navigation list as the other rows — it's unreachable by keyboard and looks visually inconsistent."
status: needs-triage
---

# Unify the Options Screen's Back Row

## Problem Statement

On the Options screen, **Win Tile**, **Theme**, **Animations**, and **Effects** are four rows in one focusable list — Up/Down moves focus between them (wrapping at both ends), and the focused row is highlighted in the accent color. **Back** is not one of these rows: it's rendered as a separate rounded-rectangle button (the same `menu_button` style used on the Main Menu and Win/Game Over screens), placed below the row list, and it's entirely outside `optionsmodel.lua`'s focus-navigation range — Up/Down can never land on it, so a keyboard-only player cannot focus or activate Back at all (the only ways back are Escape, or tapping it directly). The result the user is reporting is two related symptoms of the same root cause: Back looks different from the rows above it, and it behaves differently (not selectable in the same list), which reads as a UI inconsistency.

## Solution

Make Back a fifth row in the same focusable list as Win Tile/Theme/Animations/Effects: reachable by Up/Down (wrapping naturally includes it now), activated by Enter (mirroring Escape, which keeps working too), and rendered with the same plain centered-text row style and focus-accent-color treatment as the other four — no separate button widget.

## User Stories

1. As a keyboard-only player, I want to reach Back with Up/Down like every other row, so that I don't have to remember Escape is the only way out.
2. As a player, I want Enter to activate Back when it's focused, so that confirming a selection works the same way on every row in the list.
3. As a player, I want Back to look like a row in the same list (same font, same accent-color-when-focused treatment) instead of a separate button floating below, so the screen reads as one consistent list.
4. As a touch player, tapping Back continues to work exactly as it does today (focus it, or activate it if already focused) — this fix doesn't change touch behavior, only adds the missing keyboard path and the visual consistency.
5. As a player, Escape continues to return me to the Main Menu from any row, exactly as today — Back becoming row 5 is additive, not a replacement for Escape.
6. As a developer, I want `optionsmodel.lua`'s row abstraction to absorb an "activate, no value" row without inventing a new row type or special-casing — its existing "row with a values list" interface should already be general enough.
7. As a developer, I want `menu.lua`'s Options tree to stop building Back as a one-off `menu_button`, and instead reuse the same row-rendering helper the other four rows use, so a future sixth row doesn't require choosing between two different row styles again.
8. As a developer, I want the existing tap-routing contract (`options_hit_test` calling `on_row_tap(i)` for rows 1-4 and a distinct `on_back` for Back) preserved, so this fix is additive at the keyboard/focus layer and doesn't churn the tap-handling test surface that's already passing.

## Implementation Decisions

- **`optionsmodel.lua` needs no code changes.** Its row abstraction already only requires `values` (a non-empty list) and a `value_index`; a "Back" row can be expressed as a row with a single dummy value (e.g. `values = { true }`). `Model:left()`/`Model:right()` already degrade to a harmless no-op when a row has exactly one value (`(value_index - 2) % 1 + 1` is always `1`), and `Model:up()`/`Model:down()` already wrap across however many rows exist — so adding a fifth row to the list passed into `optionsmodel.new()` makes it focus-navigable for free, with zero new branching inside the model. This is the deep-module payoff: the model's interface didn't need to grow to absorb a new kind of row.
- **`options.lua`** (the Options screen state) is where the new row is wired up:
  - The row list built in `OptionsState:enter()` gains a fifth entry for Back (label "Back", single dummy value), alongside today's Win Tile/Theme/Animations/Effects entries. A new `BACK_ROW` constant (5) joins the existing `WIN_TILE_ROW`/`THEME_ROW`/`ANIMATIONS_ROW`/`EFFECTS_ROW` constants.
  - `persist_focused_row` gets an early-return for `BACK_ROW` — there's no config/settings value to persist for an action row.
  - `OptionsState:keypressed`: Up/Down behavior is unchanged (now naturally wraps across 5 rows instead of 4, since it delegates straight to the model). Left/Right are unchanged in shape and now harmlessly no-op when Back is focused. **New**: `"return"` now triggers the same transition Escape already does (`ctx.switch("menu")`) when the focused row is `BACK_ROW`; on every other row, Enter remains a no-op exactly as today.
  - `OptionsState:tap_row(i)`: unchanged in shape. When `i == BACK_ROW`, the existing "tap an unfocused row → focus it; tap the already-focused row → act on it" pattern naturally produces "first tap focuses Back, second tap (while already focused) activates it" — consistent with how the value rows already behave on a second tap, just with "activate" standing in for "cycle the value" since Back has none.
- **`menu.lua`**: the Options tree's Back entry stops being a `menu_button(...)` call (the rounded-rectangle button style) and becomes a fifth row built with the same row-rendering path as Win Tile/Theme/Animations/Effects (centered text, accent color when focused) — minus the `<  value  >` decoration, since Back has no value to display. The existing tap-routing contract is preserved exactly: the four value rows keep firing `callbacks.on_row_tap(i)`, and the Back row keeps firing `callbacks.on_back` — only the row's *visual construction* changes, not the callback wiring `options_hit_test` already exposes.
- **README** gets a small update to the Options section: Back is now reachable by Up/Down + Enter, not just Escape/tap.

## Testing Decisions

- Tests assert observable behavior (what `focused_row()`/`in_menu()`/persisted settings end up as after a given input), consistent with this codebase's existing style in `tests/test_options.lua` and `tests/test_optionsmodel.lua`.
- **`tests/test_options.lua`** (the deep-module surface for this fix) gains:
  - `down()` from Effects (row 4) moves focus to Back (row 5); `down()` from Back wraps back to Win Tile (row 1).
  - `up()` from Win Tile wraps to Back.
  - Left/Right on the Back row change nothing observable (no config mutation, no settings write, focus unchanged).
  - `"return"` while Back is focused returns to the Main Menu (`in_menu()` becomes true), mirroring the existing Escape test.
  - Tapping the Back row twice (focus, then activate) returns to the Main Menu, mirroring the existing "tap the already-focused row" pattern used for value rows.
  - The existing "return has no observable effect on the Options screen" test is unaffected as written (it never moves focus off row 1), but its docstring should be tightened to "...except when Back is focused" so it doesn't read as contradicting the new Back-row behavior.
- **`tests/test_menu.lua`**'s two existing Options hit-test assertions (`options_hit_test routes a tap to the matching row index...` expecting 5 interactive centers, and `...routes a tap on the Back button to on_back`) are expected to keep passing unmodified — this fix changes the Back row's visual construction and its keyboard reachability, not the tap-callback contract those tests exercise.
- **`tests/test_optionsmodel.lua`** needs no new cases — the "single-value row" behavior this fix relies on (Left/Right no-op when there's exactly one value) already follows from existing wrap-around tests; no new model behavior is introduced.

## Out of Scope

- Any change to Escape's behavior — it keeps working from every row, unchanged.
- Any change to the four value rows' own look or behavior — only Back's rendering and focus-reachability change.
- Adding Back (or an equivalent) to any other screen (Pause, Win, Game Over, Main Menu) — those screens' own button styles are untouched by this PRD.
- The Screen Stack Refactor (`docs/prd/triage/screen-stack-refactor.md`) and Defer Tileset Reload (`docs/prd/triage/defer-tileset-reload.md`) PRDs — independent of this fix; whichever lands first, this one should be re-applied against wherever `options.lua`'s logic and `menu.lua`'s Options tree end up living.

## Further Notes

This PRD was registered without a grilling session, at the user's explicit request — implementation should wait for a `/grill-me` pass. One open question worth raising then: should tapping Back when it's *not yet* focused require a second confirming tap (consistent with how the four value rows require a second tap to act), or should a single tap on Back activate it immediately, since "go back" has no destructive/value-changing risk the double-tap pattern is protecting against on the other rows? The Implementation Decisions above default to the consistent (double-tap) behavior, but this is a real product-feel question, not just a technical one.
