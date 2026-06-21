local ci = require("lib.ui.layout.compute_internals")
local testing = require("lib.ui.layout.testing")

local tests = {
    ["single element, grows correctly"] = {
        growables = { ci.Growable(0, 50) },
        remaining = 20,
        expected = { ci.Growable(0, 70) }
    },
    ["two elements, one grows"] = {
        growables = { ci.Growable(0, 50), ci.Growable(0, 60) },
        remaining = 40,
        expected = { ci.Growable(0, 75), ci.Growable(0, 75) }
    },
    ["three elements, all grow evenly"] = {
        growables = { ci.Growable(0, 50), ci.Growable(0, 60), ci.Growable(0, 70), },
        remaining = 30,
        expected = { ci.Growable(0, 70), ci.Growable(0, 70), ci.Growable(0, 70), }
    },
    ["no growth when remaining is zero"] = {
        growables = { ci.Growable(0, 50), ci.Growable(0, 60) },
        remaining = 0,
        expected = { ci.Growable(0, 50), ci.Growable(0, 60) }
    },
    ["empty list, no growth"] = {
        growables = {},
        remaining = 30,
        expected = {}
    },
}


for name, tt in pairs(tests) do
    print("running test: " .. name)
    ci.grow_along_axis(tt.growables, tt.remaining)

    if not testing.match(tt.expected, tt.growables) then
        print(string.format(
            "[%s] exp -%s- got -%s-",
            name,
            testing.PrintValue(tt.expected),
            testing.PrintValue(tt.growables)
        ))
        print("Expected: ", testing.PrintValue(tt.expected))
        print("Got: ", testing.PrintValue(tt.growables))
    end
end

print("Done.")
