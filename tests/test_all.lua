-- Run from: cd game && lua ../tests/test_all.lua
local function fresh_love_stub()
    return {
        graphics   = { getDimensions = function() return 600, 600 end },
        filesystem = {
            getDirectoryItems = function(_) return {} end,
            read              = function(_) return nil end,
            write             = function(_, _) return true end,
        },
    }
end

-- lib/ui/layout/*_test.lua is excluded: it has no love stub of its own and
-- runs under the separate `make test-ui-layout` target instead.
local find = io.popen("find . -name '*_test.lua' -not -path './lib/ui/layout/*' | sort")
local suites = {}
for path in find:lines() do
    suites[#suites + 1] = path:gsub("^%./", "")
end
find:close()

local real_exit = os.exit
local failed_suites = 0

os.exit = function(code)
    if (code or 0) ~= 0 then error("__suite_failed__") end
end

for _, path in ipairs(suites) do
    -- reset before each suite: some suites replace `love` wholesale (e.g.
    -- dropping .filesystem), which would otherwise leak into later suites
    -- that rely on the default stub.
    love = fresh_love_stub()
    local ok, err = pcall(dofile, path)
    if not ok then
        if type(err) ~= "string" or not err:find("__suite_failed__") then
            print("ERROR in " .. path .. ": " .. tostring(err))
        end
        failed_suites = failed_suites + 1
    end
end

local total = #suites
print(string.format("\n=== %d/%d suites passed ===", total - failed_suites, total))
real_exit(failed_suites > 0 and 1 or 0)
