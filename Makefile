LOVE = /Applications/love.app/Contents/MacOS/love

.PHONY: run test

run:
	$(LOVE) game

test:
	cd game && lua ../tests/test_grid.lua
