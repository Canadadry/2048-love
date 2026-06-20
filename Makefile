LOVE = /Applications/love.app/Contents/MacOS/love
GAME = .

.PHONY: run test

run:
	$(LOVE) $(GAME)

test:
	lua tests/test_grid.lua
