# tileset-builder

Converts GIF animations into PNG sprite sheets compatible with the game's tileset loader.

## Setup

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install pillow
```

## Usage

**Create** a fresh tilesheet from a list of GIFs (row order = argument order):

```sh
python tilesheet.py create tile_2.gif tile_4.gif tile_8.gif
```

`--output` defaults to `output.png`; `--tile-width` defaults to the GIF's native width and `--tile-height` defaults to that width scaled to the first GIF's native aspect ratio. Both can be overridden:

```sh
python tilesheet.py create --output sheet.png --tile-width 64 tile_2.gif tile_4.gif tile_8.gif
```

Pass both `--tile-width` and `--tile-height` to force a square tile regardless of source GIF shapes:

```sh
python tilesheet.py create --tile-width 64 --tile-height 64 tile_2.gif tile_4.gif tile_8.gif
```

When `--tile-height` is given, it is no longer derived from the first GIF's aspect ratio — the first GIF (row 0) may then need `--shrink` or `--crop` itself if its native aspect doesn't match the forced tile shape, the same way later rows already do.

**Append** a new row to an existing tilesheet:

```sh
python tilesheet.py append output.png tile_16.gif
```

If a row's frame count would make the sheet wider than 16384px (the common GPU texture-size floor), `create`/`append` automatically downsample that row — keeping frames evenly spread across the original clip — and print a notice naming the GIF and the before/after frame count. A tile width that alone exceeds 16384px is a hard error, since not even one frame would fit.

Both commands produce two files:
- `output.png` — sprite sheet, 13 rows × N frames, all frames `tile_size × tile_size`
- `output.lua` — sidecar read by the game, contains `tile_size` and per-row `frame_counts`

## Output format

```
output.png  →  width  = max(frame_counts) * tile_width
               height = row_count * tile_height

output.lua  →  return {
                 tile_width = 64,
                 tile_height = 48,
                 frame_counts = { 4, 2, 8, ... },
               }
```

Rows with fewer frames than the max are padded with transparent tiles on the right.

## Tests

```sh
source .venv/bin/activate
pip install pytest
pytest tests/
```
