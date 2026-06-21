LOVE = /Applications/love.app/Contents/MacOS/love
LOVE_FILE = 2048.love

.PHONY: run dev build test-game test-tool-tileset test-tool-dl test-tool-theme test-all dl theme themes

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

test-tool-theme:
	cd tools/theme-builder && python3 -m unittest tests.test_build -v

test-all: test-game test-tool-tileset test-tool-dl test-tool-theme

dl:
	cd tools/curl-giphy && source .venv/bin/activate && python3 giphy_dl.py $(URL)

theme:
	cd tools/theme-builder && python3 build.py ../../themes/$(NAME).txt $(if $(MAX_SIZE),--max-size $(MAX_SIZE),)

themes:
	./tools/theme-builder/build_missing.sh $(MAX_SIZE)
