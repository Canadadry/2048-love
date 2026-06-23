# 2048

A Love2D implementation of the 2048 puzzle game — designed to run with animated GIF tilesets so every tile value can display a custom sprite animation instead of a plain colored square.

![Screenshot](docs/screen1.png)

## Requirements

- [LÖVE](https://love2d.org/) 11.x

## Play

```
make run      # normal game (win at 2048)
make dev      # win at 32 — useful for testing the win screen
```

The game opens with a **Main Menu** — Up/Down to navigate, Enter (or tap) to confirm. Select **New Game** to start playing or **Quit** to exit.

Arrow keys to slide tiles. The window is resizable.

When you create a 2048 tile a **You Win** overlay appears with two options — **Continue** (keep playing) and **Restart** — navigated with Up/Down and confirmed with Enter, or tapped directly. A burst of 50-100 colored squares explodes across the screen and falls under gravity as the overlay appears (suppressed when the **Effects** option is off). A **Game Over** overlay appears when no moves remain; press Enter or any arrow key (or tap) to restart.

Press `Escape` (or tap the **⏸** button above the board's top-right corner) to open the **Pause** menu. The board stays visible behind a full-window dimmed overlay. Up/Down to navigate, Enter to confirm. Options: **Resume**, **New Game**, **Main Menu**, **Quit**. Pressing `Escape` again or selecting Resume returns instantly to the game.

Select **Options** from the main menu (between New Game and Quit) to open the **Options** screen — a five-row list: **Win Tile**, **Theme**, **Animations**, **Effects**, **Back**. Up/Down moves focus between the rows (wrapping at both ends); the focused row is highlighted. Left/Right cycles the focused row's value immediately — no confirm step (a no-op on Back, which has no value). Tapping an unfocused row focuses it; tapping the already-focused row cycles it forward (wrapping), same as Right — for Back, that second tap activates it. **Win Tile** toggles between `32` (dev) and `2048` (prod) — the same value `--win-tile` sets at launch, but changeable mid-session. **Theme** cycles through the built tilesheets in `game/assets/` (plus a "None (classic)" entry). **Animations** toggles the slide animation on/off — when off, moves snap to their destination instantly. **Effects** toggles the merge pop/scale effect on/off, independent of slide animation. Enter has no effect except on the Back row, where it returns to the main menu. Press `Escape` from any row, or focus and confirm **Back** (Enter or a second tap), to return to the main menu.

All four settings persist across launches — they're saved to disk as soon as you change them, and restored on the next launch. `--win-tile` at launch still overrides a saved Win Tile value.

## Test

```
make test-game          # pure-Lua game logic tests (no Love2D runtime needed)
make test-tool-tileset  # tileset-builder Python tests
make test-tool-dl       # curl-giphy Python tests
make test-tool-theme    # theme-builder Python tests
make test-all           # all of the above
```

## Tools

### curl-giphy

Downloads a GIF from a Giphy page URL and saves it to the current directory.

```
make dl URL=https://giphy.com/gifs/<slug>
```

### tileset-builder

Converts a set of GIFs into a PNG sprite sheet compatible with the game's tileset loader. Each GIF becomes one row (one tile value); animation frames are preserved.

```sh
cd tools/tileset-builder
source .venv/bin/activate
python tilesheet.py create tile_2.gif tile_4.gif tile_8.gif ...
```

See `tools/tileset-builder/README.md` for the full usage and output format.

### theme-builder

Turns a theme manifest (`themes/<name>.txt`, one Giphy URL per line, line order = tile value order) into a ready-to-use tilesheet in one command — orchestrates `curl-giphy` and `tileset-builder` without modifying either.

```
make theme NAME=jurassic-park
```

Downloaded GIFs are cached under `themes/<name>/raw/` so reruns only re-download lines that changed. Output lands in `game/assets/<name>.png` plus its `.lua` sidecar. See `tools/theme-builder/docs/prd/theme-builder.md` for design details.
