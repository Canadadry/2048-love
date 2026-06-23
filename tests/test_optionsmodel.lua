local optionsmodel = require("lib.optionsmodel")

local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("PASS " .. name)
        pass = pass + 1
    else
        print("FAIL " .. name)
        print("     " .. tostring(err))
        fail = fail + 1
    end
end

local function eq(a, b, msg)
    if a ~= b then
        error((msg or "eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

-- ── Cycle 1: Tracer bullet ────────────────────────────────────────────────────

test("next() returns the value following the current one", function()
    eq(optionsmodel.next({ 32, 2048 }, 32), 2048, "next value after 32")
end)

-- ── Cycle 2: next() wraps from the last value to the first ──────────────────

test("next() wraps from the last value back to the first", function()
    eq(optionsmodel.next({ 32, 2048 }, 2048), 32, "next value wraps to 32")
end)

-- ── Cycle 3: prev() returns the value preceding the current one ─────────────

test("prev() returns the value preceding the current one", function()
    eq(optionsmodel.prev({ 32, 2048 }, 2048), 32, "prev value before 2048")
end)

-- ── Cycle 4: prev() wraps from the first value to the last ──────────────────

test("prev() wraps from the first value back to the last", function()
    eq(optionsmodel.prev({ 32, 2048 }, 32), 2048, "prev value wraps to 2048")
end)

-- ── Cycle 5: next()/prev() work over a 3-value list, e.g. themes ────────────

test("next() steps through a 3-value list in order", function()
    local values = { "", "jurassic-park", "ocean" }
    eq(optionsmodel.next(values, ""), "jurassic-park", "first to second")
    eq(optionsmodel.next(values, "jurassic-park"), "ocean", "second to third")
    eq(optionsmodel.next(values, "ocean"), "", "third wraps to first")
end)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
