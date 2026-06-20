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
python tilesheet.py create output.png --tile-size 64 tile_2.gif tile_4.gif tile_8.gif
```

**Append** a new row to an existing tilesheet:

```sh
python tilesheet.py append output.png tile_16.gif
```

Both commands produce two files:
- `output.png` — sprite sheet, 13 rows × N frames, all frames `tile_size × tile_size`
- `output.lua` — sidecar read by the game, contains `tile_size` and per-row `frame_counts`

## Output format

```
output.png  →  width  = max(frame_counts) * tile_size
               height = row_count * tile_size

output.lua  →  return {
                 tile_size = 64,
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
