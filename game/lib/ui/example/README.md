# lib/ui example: a standalone main menu

A minimal, self-contained demo of `lib/ui` — builds a title plus three
buttons, centered on screen, using only `lib/ui`'s `builder` DSL and
`painter` module. It doesn't import or depend on any of the game's own code
(`menu.lua`, `renderer/`, etc.) — this is what using `lib/ui` from scratch
looks like.

## Run it

```sh
make ui-example
```

(or `cd game && lua lib/ui/example/main.lua` directly). No LÖVE runtime
required — it stubs the handful of `love.graphics` calls it needs, the same
way `tests/test_all.lua` does, so it runs under plain `lua`.

## What it does

Builds this tree:

```lua
local function Button(label)
    return builder.Node(
        "w-240 h-60 center",
        painter.Rectangle { color = { 237, 227, 217, 255 }, rounded = 6, segment = 8 },
        { builder.Leaf("grow-x h-fit", painter.Text { text = label, align = "center" }) }
    )
end

local tree = painter.Tree()
builder.Build(tree, builder.Node(
    string.format("w-%d h-%d center", SCREEN_W, SCREEN_H),
    nil,
    {
        builder.Node("col gap-16 center", nil, {
            builder.Leaf("grow-x h-fit", painter.Text { text = "2048", align = "center" }),
            Button("New Game"),
            Button("Options"),
            Button("Quit"),
        }),
    }
))
ui.DrawTree(tree)
```

and prints the computed layout:

```
lib/ui main menu, computed via ui.DrawTree:
  <group>   x=0 y=0 w=600 h=600
  <group>   x=180 y=179 w=240 h=242
  Text      x=180 y=179 w=240 h=14
  Rectangle x=180 y=209 w=240 h=60
  Text      x=180 y=232 w=240 h=14
  Rectangle x=180 y=285 w=240 h=60
  Text      x=180 y=308 w=240 h=14
  Rectangle x=180 y=361 w=240 h=60
  Text      x=180 y=384 w=240 h=14
```

No pixel math anywhere — the screen-sized root frame centers the column,
the column stacks its children with a 16px gap, and each button centers its
label. Resize the screen and every number above recomputes on its own.

## Reading the code, piece by piece

Open `main.lua` alongside this section.

1. **The love stub** — just enough of `love.graphics` (a fake font, no-op
   draw calls) for `painter.lua` to run without an actual window. Same trick
   the real test suite (`tests/test_all.lua`) uses to run headless.

2. **`builder.Node(classes, painter, children)` / `builder.Leaf(classes, painter)`**
   — `lib/ui/layout/builder.lua` is a space-separated class-string DSL,
   mirroring [zui's `builder.zig`](https://github.com/Canadadry/zui/blob/master/src/builder.zig),
   that builds `frame.Frame` trees without writing nested `frame.Frame{}` /
   `ui.Node` / `ui.Leaf` calls by hand. See the doc comment at the top of
   `builder.lua` for the full class vocabulary (`row`/`col`/`stack`,
   `grow`/`w-N`/`h-N`/`w-fit`/`w-grow`, `p-N`/`px-`/`py-`/`gap-N`,
   `center`/`ax-*`/`ay-*`, `x-N`/`y-N`).

3. **The root node** — `w-600 h-600 center` sizes the root to the whole
   screen and centers its one child (the column) both horizontally and
   vertically. `align` on a node governs how *that node* positions its own
   children, not how it's positioned by its parent — that's why `center`
   lives on the root, not on the column.

4. **`col gap-16 center`** *is* the stack-with-gap primitive: a `Vertical`
   layout with a margin between children, plus `center` so the title (which
   is narrower than the 240px buttons) and the buttons all align on the same
   x-axis. There's no `top_y + (btn_h + gap) * i` anywhere — the engine
   spaces the children for you.

5. **Each button is a `Node` wrapping a `Leaf`**, not a single Frame: the
   outer `Node` draws the background and centers its child; the inner
   `Leaf` draws the label and uses `grow-x` to fill the button's width (a
   childless `Leaf` sized with `w-fit` collapses to zero width — only
   `grow` consults the painter's natural size as a floor). This
   "background + centered content" shape is the pattern to reuse for any
   button.

6. **`builder.Build(tree, spec)`** walks the declarative spec tree above and
   calls `ui.Node`/`ui.Leaf` for you; **`ui.DrawTree(tree)`** then runs the
   actual layout passes and fills `tree.Commands` with `{x, y, w, h,
   painter}` — the same shape a real game would use both to draw (loop over
   `Commands`, call `painter.Draw`) and to hit-test taps.
