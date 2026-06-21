# lib/ui example: rebuilding the main menu buttons

This is a hands-on companion to `lib/ui/README.md`, built specifically to
prepare for the `/grill-me` session that `docs/prd/triage/menu-layout-system.md`
requires before any layout-system implementation starts. Read this before
that session — it gives you working code and real numbers to argue about
instead of abstractions.

## Run it

```sh
make ui-example
```

(or `cd game && lua lib/ui/example/main.lua` directly). No LÖVE runtime
required — it stubs the handful of `love.graphics` calls it needs, the same
way `tests/test_all.lua` does, so it runs under plain `lua`.

## What it does

It takes the **real** `menu.lua` code — `menu.main_menu_button_bounds()`,
unmodified — and prints the three button boxes it hand-computes today:

```
hand-rolled (menu.main_menu_button_bounds):
  New Game   x=180 y=244 w=240 h=79
  Options    x=180 y=344 w=240 h=79
  Quit       x=180 y=444 w=240 h=79
```

Then it builds the *same three buttons* as a `lib/ui` tree and prints what
`ui.DrawTree` computes for them:

```
lib/ui (computed via ui.DrawTree):
  rect       x=180 y=244 w=240 h=79
  rect       x=180 y=344 w=240 h=79
  rect       x=180 y=444 w=240 h=79
```

Same pixels. That's the point: this isn't a toy demo unrelated to the game,
it's proof that `lib/ui` can reproduce a screen `menu.lua` already draws,
without hand-deriving `top_y + (btn_h + gap) * i` for each button.

## Reading the code, piece by piece

Open `main.lua` alongside this section.

1. **The love stub** — just enough of `love.graphics` (a fake font,
   no-op draw calls) for `menu.lua` and `painter.lua` to run without an
   actual window. This is what lets the example (and the real test suite)
   run headless.

2. **`local hand_rolled = menu.main_menu_button_bounds()`** — this calls
   the production function as-is. We don't reimplement or copy its math;
   we read its output (`btn_w`, `btn_h`, `gap`, `btn_x`, `top_y`) so the
   `lib/ui` version is anchored to the exact same screen, not invented
   numbers.

3. **The root `ui.Node`**:
   ```lua
   ui.Node(tree, frame.Frame {
       pos    = frame.Pos(btn_x, top_y),
       size   = frame.Size(btn_w, total_h),
       layout = frame.Layout.Vertical(),
       margin = gap,
   }, nil, function(tree) ... end)
   ```
   This is the whole "stack" concept from the PRD's open questions: a
   `Vertical` layout with a `margin` *is* the stack-with-gap primitive.
   There's no `top_y + (btn_h + gap) * i` anywhere — the engine spaces the
   children for you.

4. **Each button is a `Node` wrapping a `Leaf`**, not a single Frame:
   ```lua
   ui.Node(tree, frame.Frame {
       size = frame.Size(btn_w, btn_h),
       align = frame.Align(frame.Align.Middle(), frame.Align.Middle()),
       painter = painter.Rectangle{ ... },
   }, nil, function(tree)
       ui.Leaf(tree, frame.Frame {
           size = frame.Size(frame.Size.Grow(), frame.Size.Fit()),
           painter = painter.Text{ text = b.label, align = "center" },
       })
   end)
   ```
   The outer `Node` draws the button background and centers its child; the
   inner `Leaf` draws the label and grows to fill the button's width. This
   two-frame "background + centered content" shape is how every button in
   the upstream example is built — it's the pattern to reuse for every
   button across `menu.lua`'s five screens, not just this one.

5. **`ui.DrawTree(tree)`** runs the actual layout passes and fills
   `tree.Commands` with `{x, y, w, h, painter}` — exactly the shape
   `main.lua`'s `handle_tap()` would need for hit-testing, see below.

## Question bank for the grilling session

Each open question in the PRD maps directly onto something this example
makes concrete:

- **"Generic reusable layout primitive, or a thin button-list helper?"**
  This example uses the *generic* primitive (`Frame`/`Layout.Vertical`/
  `margin`) directly, with no menu-specific helper layered on top. Look at
  how much boilerplate is still here (the `Node`-wrapping-`Leaf` pattern
  repeated per button) and decide: is a thin `Button(label, painter)`
  helper worth adding on top of `lib/ui`, or does every screen just write
  this shape inline?

- **"Do `menu.lua`'s five `draw_*`/`*_button_bounds` pairs get rebuilt on
  top of it?"** This example only rebuilt `main_menu_button_bounds()`'s
  *button list*; `draw_main_menu()`'s title text and background are still
  hand-drawn. Walk through `menu.lua`'s other four screens (options, pause,
  win, game-over) and check whether they all fit this same
  Vertical-stack-of-buttons shape, or whether some (e.g. the options screen
  with its row-cycling values) need something this example doesn't cover.

- **"How does `main.lua`'s `handle_tap()` consume the same layout output?"**
  `tree.Commands` already has `{x, y, w, h}` per drawn box — same shape
  `*_button_bounds()` returns today. The open question is *order and
  identity*: `handle_tap()` needs to know which command is "Options" vs
  "Quit", and `Commands` is a flat draw-order list with no labels attached.
  Decide whether buttons need a tag/id field threaded through, or whether
  hit-testing should walk the same `frame.Frame` tree separately from
  `Commands`.

- **"Does this touch `renderer/board.lua`'s `board_metrics()`?"** This
  example deliberately did *not* touch `board_metrics()` — it borrowed
  `menu.lua`'s already-computed numbers as the root `Frame`'s `pos`/`size`.
  Decide whether that's the right boundary going forward (board metrics
  stay hand-computed; only the per-screen widget layout adopts `lib/ui`),
  or whether the board area itself should become a `Frame` too.
