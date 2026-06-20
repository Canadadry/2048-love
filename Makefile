LOVE = /Applications/love.app/Contents/MacOS/love
LOVE_FILE = 2048.love

.PHONY: run dev build test-game test-tool-tileset test-tool-dl test-all dl

build:
	cd game && zip -r ../$(LOVE_FILE) .

run:
	$(LOVE) game

dev:
	$(LOVE) game --win-tile=32

test-game:
	cd game && lua ../tests/test_all.lua

test-tool-tileset:
	cd tools/tileset-builder && source .venv/bin/activate && pytest tests/

test-tool-dl:
	cd tools/curl-giphy && source .venv/bin/activate && python3 -m unittest test_giphy_dl -v

test-all: test-game test-tool-tileset test-tool-dl

dl:
	cd tools/curl-giphy && source .venv/bin/activate && python3 giphy_dl.py $(URL)
