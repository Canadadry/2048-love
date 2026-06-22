---
title: "Anchor the Pause Icon to the Board (HUD Tree Port)"
description: "The pause icon sits in a fixed window corner unrelated to the board's position, making it hard to reach/tap reliably on touch devices; it should anchor to the board like the score already does."
status: done
---

# Anchor the Pause Icon to the Board (HUD Tree Port)

## Problem Statement

`menu.lua`'s `pause_icon_bounds()` fixes the pause icon at `{ x = 8, y = 8, w = sz, h = sz }` — pinned to the extreme top-left corner of the *window*, with only an 8px margin, regardless of where the board actually sits on screen. On wide or tall windows the board can be centered far from that corner, so the icon ends up spatially unrelated to anything else the player is looking at. The user reports it's too far up-left to be clicked reliably on a touch device.

This is inconsistent with the score, which already anchors to the board (`renderer/hud.lua`'s `score_position` returns `board_x, board_y - font_sz - 4`, i.e. just above the board's left edge). The pause icon should follow the same convention instead of living in a disconnected absolute corner.

## Solution

Move the pause icon so it anchors to the board's top-right corner, sharing a single HUD row with the score: the score sits at the row's left (growing to fill available width), the icon sits at the row's right, both vertically centered against each other, with a small inset gap from the board's right edge and from the board's top edge. Both the score and the icon are ported onto the project's existing `lib/ui` layout/painter tree system — the same `builder.Build` / `painter.Draw` / `ui.HitTest` pattern already used for the main menu, options, win, and game-over screens — instead of hand-rolled pixel math, so the icon's draw position and its tap target can never drift apart.

Ownership of this combined score+icon HUD moves to `renderer/hud.lua`, which grows from a plain score-printing helper into the owner of the HUD tree (build, draw, and hit-test). `menu.lua`'s `pause_icon_bounds()`/`draw_pause_icon()` are removed — `menu.lua` keeps owning only the full-screen modal overlays (main menu, options, the *pause screen* with Resume/New Game/Main Menu/Quit, win, game over), not this persistent in-game HUD element.

## User Stories

1. As a touch player, I want the pause icon positioned near the board instead of in a far window corner, so that I can reach it reliably without searching for it.
2. As a touch player, I want the pause icon's visible position and its tappable area to always match exactly, so that tapping where I see the icon always works.
3. As a player on any window size/aspect ratio, I want the pause icon to stay sensibly placed relative to the board as the window is resized, so that the icon doesn't end up oddly placed on unusual window shapes.
4. As a player, I want the score to keep appearing in the same general "above the board" location it does today, so that this change doesn't relocate information I'm already used to finding.
5. As a player, I want the pause icon and score to read as one visually balanced row (icon right, score left, vertically aligned), so that the HUD looks deliberate rather than like two unrelated floating elements.
6. As a player, I want the pause icon to keep disappearing while paused, on the win screen, and on the game-over screen (exactly as it does today), so that I'm not shown a tap target that doesn't do anything meaningful in those states.
7. As a player, I want tapping the relocated icon to open the Pause screen exactly as today (same as pressing Escape), so that the only thing that changed is where the icon is, not what it does.
8. As a player, I want the icon to keep meeting the 44x44 minimum touch-target size it already has, so that this position fix doesn't regress the size fix that came before it.
9. As a desktop/mouse player, I want clicking the relocated icon to keep working exactly like it does for touch, so that the fix doesn't regress mouse-based interaction.
10. As a developer, I want the pause icon's draw position and hit-test target built from one shared tree, so that a future layout tweak can't desync visuals from tap targets the way the old hand-rolled `pause_icon_bounds()` function could.
11. As a developer, I want the score and pause icon's combined layout expressed as a single declarative row (using the same `lib/ui` builder vocabulary already used elsewhere in the codebase), so that there's one source of truth for this HUD's geometry instead of independently-hand-computed pixel formulas.
12. As a developer, I want `renderer/hud.lua` to be the sole owner of this HUD tree (build, draw, hit-test), so that `menu.lua` stays scoped to full-screen modal overlays and doesn't grow an unrelated persistent-HUD responsibility.
13. As a developer maintaining `main.lua`, I want the pause-icon tap-routing call site to look structurally like the other screens' hit-test call sites (`options_hit_test`, `win_hit_test`, etc.), so that the HUD's tap handling doesn't need a bespoke pattern.

## Implementation Decisions

- **Anchor point**: the pause icon anchors to the board's top-right corner instead of the window's top-left corner. Concretely, it shares one HUD row with the score: a row container sized to the board's width, height fit to its tallest child, positioned just above the board (mirroring how the score already sits just above the board today).
- **Horizontal alignment**: the score Text leaf is set to grow and fill the row's available width, which naturally pushes the icon to the row's trailing edge — no explicit "align end" needed beyond the grow behavior. The icon is inset from the board's right edge by the same `pad` value already computed by the board's metrics helper (`max(4, floor(tile_px * 0.05))`) — i.e. the same constant used today for inter-tile spacing, reused here for this inset rather than introducing a new gap constant.
- **Vertical alignment**: the row centers its children on its cross-axis, so the icon and the score text are vertically centered against each other automatically — no separate font-height math is computed to align them. The row's height is sized to fit its tallest child (the icon, since it has a fixed minimum touch-target size that exceeds the score text's height).
- **Vertical gap from the board**: the row's bottom edge sits the same `pad` distance above the board's top edge, reusing the same constant as the horizontal inset rather than a distinct value.
- **Layout/painter tree port**: this is not just a position tweak — score and icon both move onto the project's existing declarative tree system (the same one already used for the main menu, options, win, and game-over screens). The row is a single tree positioned via the layout builder's screen-anchoring mechanism; the score is a Text leaf that grows to fill remaining width; the icon is a fixed-size node combining a custom-drawn visual (the existing two-bar icon graphic, unchanged visually) with the tree system's existing tap-detection mechanism — the same composition pattern (visual + tap detection bundled together) already used for every other button in the codebase.
- **Conditional icon visibility**: the icon only appears during active gameplay (not while paused, not on the win screen, not on the game-over screen) — this exactly matches today's behavior, just expressed as a single flag passed into one draw call instead of a separate draw call guarded by an `else` branch.
- **Module ownership**: `renderer/hud.lua` becomes the sole owner of this HUD tree — it gains the tree-building, drawing, and hit-testing responsibility that today is split between a plain score-print function (in `hud.lua`) and the icon's bounds/draw functions (in `menu.lua`). `menu.lua` loses its pause-icon functions entirely; it keeps the *pause screen* (the dimmed full-board overlay with Resume/New Game/Main Menu/Quit buttons), which is an unrelated, separate piece of UI from this small persistent icon.
- **Metrics access**: `hud.lua` computes its own board metrics by calling the board module's existing metrics helper directly, rather than having board geometry threaded through its call sites as parameters. This matches the established convention elsewhere in the codebase, where each screen/HUD function independently derives the geometry it needs rather than passing a long parameter chain through callers.
- **Call-site shape**: the rendering call site collapses today's "always draw score, separately draw the icon only in the gameplay branch" into a single call that always draws the score and conditionally draws the icon based on one boolean (whether the player is in active, unpaused gameplay). The tap-routing call site (in the input-handling code) collapses today's manual bounds-check-then-fire-callback into a single hit-test call that takes the same shape as every other screen's hit-test call (build the tree, route a tap through it, invoke a named callback on a hit, do nothing on a miss).

## Testing Decisions

- A good test here verifies *observable behavior* — where the icon's tappable area actually ends up relative to the board, and whether a tap in/out of that area fires/doesn't fire the right callback — not the internal tree structure used to get there. This mirrors the existing tests for other screens' hit-testing (e.g. `options_hit_test`'s tests in `tests/test_menu.lua`, which tap computed row centers and assert the right callback fires, and assert a miss fires nothing).
- New tests (in a new `tests/test_hud.lua`, since this responsibility moves out of `menu.lua`) should cover:
  - The icon's computed position is anchored correctly relative to the board: its trailing edge sits the expected `pad` distance from the board's right edge, and its vertical center lines up with the score text's vertical center.
  - The icon still meets the existing 44x44 minimum touch-target size (carrying forward the existing size-only assertion that's being removed from `tests/test_menu.lua`).
  - A tap inside the icon's computed area fires the pause callback; a tap outside it fires nothing.
  - Drawing with the icon hidden (e.g. while paused) renders the score without erroring and without an icon present.
- The old `pause_icon_bounds` tests in `tests/test_menu.lua` (the "returns a single rect with positive finite dimensions" and "at least 44x44 for touch targets" tests) are removed from that file, since the function they test no longer lives in `menu.lua`.
- No existing test exercises the pause icon's tap-handling through `main.lua`'s input dispatch today, so there's no call site there to migrate — but the manual verification pass for this change should confirm tapping the relocated icon still opens the Pause screen, on both a touch-simulated tap and a desktop click.

## Out of Scope

- A broader audit of touch-target *position* (as opposed to size) on other screens — this PRD is scoped to the pause icon only.
- Device safe-area handling (notches, rounded corners) — not addressed.
- A known minor edge case: at the app's absolute minimum supported window size, the HUD row's computed top can land a couple of pixels above the window's visible top edge, because the board's existing top margin was originally sized for a slim score line, not a full touch-target-sized icon. This was raised and explicitly accepted as a negligible, out-of-scope edge case rather than fixed here.

## Further Notes

This PRD started life merged with a second bug ("Options screen unusable via touch") in `docs/prd/triage/touch-usability-fixes.md`. That other bug was found to already be resolved by PRDs 013, 019, and 021 — the triage placeholder has been deleted now that its one remaining open item is captured here.
