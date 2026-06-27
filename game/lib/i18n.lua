local M = {}

local _data   = {}
local _langs  = {}
local _codes  = {}
local _active = "en"

local function split_line(line)
    local cols = {}
    local i = 1
    while i <= #line do
        if line:sub(i, i) == '"' then
            local field = ""
            i = i + 1
            while i <= #line do
                local c = line:sub(i, i)
                if c == '"' then
                    if line:sub(i + 1, i + 1) == '"' then
                        field = field .. '"'; i = i + 2
                    else
                        i = i + 1; break
                    end
                else
                    field = field .. c; i = i + 1
                end
            end
            cols[#cols + 1] = field
            if line:sub(i, i) == ',' then i = i + 1 end
        else
            local j = line:find(',', i, true) or (#line + 1)
            cols[#cols + 1] = line:sub(i, j - 1)
            i = j + 1
        end
    end
    return cols
end

local function parse(str)
    local data, langs, codes = {}, {}, {}
    local header
    for line in (str .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then
            local cols = split_line(line)
            if not header then
                header = cols
                for i = 2, #header do
                    langs[#langs + 1] = { code = header[i], name = header[i] }
                    codes[header[i]] = true
                end
            else
                local key = cols[1]
                local row = {}
                for i = 2, #header do
                    row[header[i]] = cols[i] or ""
                end
                data[key] = row
            end
        end
    end
    local name_row = data["lang.name"]
    if name_row then
        for _, lang in ipairs(langs) do
            if name_row[lang.code] and name_row[lang.code] ~= "" then
                lang.name = name_row[lang.code]
            end
        end
    end
    return data, langs, codes
end

function M.load(csv_string)
    _data, _langs, _codes = parse(csv_string)
    _active = "en"
end

function M.set_lang(code)
    _active = _codes[code] and code or "en"
end

function M.lang()
    return _active
end

function M.languages()
    local result = {}
    for _, lang in ipairs(_langs) do
        result[#result + 1] = { code = lang.code, name = lang.name }
    end
    return result
end

function M.t(key)
    local row = _data[key]
    if not row then return key end
    local v = row[_active]
    if v and v ~= "" then return v end
    v = row["en"]
    if v and v ~= "" then return v end
    return key
end

return M
