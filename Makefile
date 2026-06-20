LOVE = /Applications/love.app/Contents/MacOS/love

.PHONY: run test test-tools

run:
	$(LOVE) game

test:
	cd game && lua ../tests/test_grid.lua && lua ../tests/test_tile.lua && lua ../tests/test_gamestate.lua

test-tools:
	cd tools/tileset-builder && source .venv/bin/activate && pytest tests/
