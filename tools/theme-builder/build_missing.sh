#!/bin/sh
# Builds every themes/*.txt manifest that doesn't yet have a game/assets/<name>.png output.
# Run from the repo root (e.g. via `make themes` or `make themes MAX_SIZE=64`).
set -e

max_size="$1"

cd "$(dirname "$0")/../.."

for f in themes/*.txt; do
	name=$(basename "$f" .txt)
	if [ -f "game/assets/$name.png" ]; then
		echo "Skipping $name (already built)"
	else
		echo "Building $name"
		if [ -n "$max_size" ]; then
			python3 tools/theme-builder/build.py "$f" --max-size "$max_size"
		else
			python3 tools/theme-builder/build.py "$f"
		fi
	fi
done
