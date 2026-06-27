local function make_source()
    return {
        _playing   = false,
        _looping   = false,
        play       = function(self) self._playing = true end,
        stop       = function(self) self._playing = false end,
        isPlaying  = function(self) return self._playing end,
        setLooping = function(self, v) self._looping = v end,
    }
end

local sources_created = {}

love = {
    audio = {
        newSource = function(path, kind)
            local s = make_source()
            s._path = path
            s._kind = kind
            sources_created[#sources_created + 1] = s
            return s
        end,
    },
    graphics   = { getDimensions = function() return 600, 600 end },
    filesystem = {
        write             = function(_, _) return true end,
        read              = function(_) return nil end,
        getDirectoryItems = function(_) return {} end,
    },
}

local config = require("config")
local music  = require("lib.music")
local T      = require("lib.t")
local test   = T.test
local eq     = T.eq

local function reset()
    sources_created      = {}
    music._reset()
    config.MUSIC.ENABLED = true
end

-- ── Cycle 1: play() starts a streaming looping source ────────────────────────

test("play() creates a streaming looping source and plays it", function()
    reset()
    music.play("assets/music/menu.mp3")
    eq(#sources_created, 1, "one source created")
    eq(sources_created[1]._kind, "stream", "source is a stream")
    eq(sources_created[1]._playing, true, "source is playing")
    eq(sources_created[1]._looping, true, "source loops")
end)

-- ── Cycle 2: play() same path does not restart ───────────────────────────────

test("play() with the same path does not create a new source", function()
    reset()
    music.play("assets/music/menu.mp3")
    music.play("assets/music/menu.mp3")
    eq(#sources_created, 1, "still one source after duplicate play call")
end)

-- ── Cycle 3: play() different path stops old and plays new ───────────────────

test("play() with a different path stops the current source and starts a new one", function()
    reset()
    music.play("assets/music/menu.mp3")
    local first = sources_created[1]
    music.play("assets/music/game.mp3")
    eq(first._playing, false, "first source stopped when switching tracks")
    eq(#sources_created, 2, "new source created for the new path")
    eq(sources_created[2]._path, "assets/music/game.mp3", "new source uses the new path")
    eq(sources_created[2]._playing, true, "new source is playing")
end)

-- ── Cycle 4: stop() stops the current source ─────────────────────────────────

test("stop() stops the currently playing source", function()
    reset()
    music.play("assets/music/menu.mp3")
    music.stop()
    eq(sources_created[1]._playing, false, "source stopped by stop()")
end)

-- ── Cycle 5: play() while MUSIC.ENABLED is false does nothing ─────────────────

test("play() while config.MUSIC.ENABLED is false does not start any source", function()
    reset()
    config.MUSIC.ENABLED = false
    music.play("assets/music/menu.mp3")
    eq(#sources_created, 0, "no source created when music is disabled")
    config.MUSIC.ENABLED = true
end)

-- ── Cycle 6: play() after stop() restarts the track ──────────────────────────

test("play() after stop() creates a new source and plays it", function()
    reset()
    music.play("assets/music/menu.mp3")
    music.stop()
    sources_created = {}
    music.play("assets/music/menu.mp3")
    eq(#sources_created, 1, "new source created after stop")
    eq(sources_created[1]._playing, true, "new source plays")
end)

-- ── Cycle 7: play() without love.audio is a safe no-op ───────────────────────

test("play() is a safe no-op when love.audio is absent", function()
    reset()
    local saved_audio = love.audio
    love.audio        = nil
    local ok, _       = pcall(function() music.play("assets/music/menu.mp3") end)
    love.audio        = saved_audio
    eq(ok, true, "no error when love.audio is absent")
    eq(#sources_created, 0, "no source created without love.audio")
end)

T.report()
