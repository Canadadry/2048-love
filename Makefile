LOVE = /Applications/love.app/Contents/MacOS/love
LOVE_FILE = 2048.love

.PHONY: run build test test-tools dl

build:
	cd game && zip -r ../$(LOVE_FILE) .

run:
	$(LOVE) game

test:
	cd game && lua ../tests/test_grid.lua && lua ../tests/test_tile.lua && lua ../tests/test_gamestate.lua && lua ../tests/test_tileset.lua

dl:
	cd tools/curl-giphy && source .venv/bin/activate && python3 giphy_dl.py $(URL)

test-tools:
	cd tools/tileset-builder && source .venv/bin/activate && pytest tests/
	cd tools/curl-giphy && source .venv/bin/activate && python3 -m unittest test_giphy_dl -v
