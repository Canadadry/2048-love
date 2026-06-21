# theme-builder

Turns a theme manifest into a ready-to-use tilesheet by orchestrating `curl-giphy` and `tileset-builder`. Pure glue — no third-party dependencies, no changes to either existing tool.

## Usage

```sh
python3 build.py themes/<name>.txt
```

or via the root Makefile:

```
make theme NAME=<name>
```

## Manifest format

`themes/<name>.txt` — one Giphy URL per line, in tile-value order (line 1 → tile 2, line 2 → tile 4, ... up to line 13 → tile 8192). Blank lines are ignored. More than 13 non-blank lines is a validation error.

## Output

- `themes/<name>/raw/*.gif` — cached downloads (gitignored); reruns skip files already present.
- `game/assets/<name>.png` + `game/assets/<name>.lua` — the built tilesheet, written by `tileset-builder`.

## Tests

```sh
python3 -m unittest tests.test_build -v
```

or `make test-tool-theme` from the repo root. Fully offline — all subprocess calls are mocked.
