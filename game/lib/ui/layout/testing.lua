local function PrintValue(val, indent)
    if type(val) ~= "table" then
        return tostring(val)
    end
    local ret = "{"
    if type(indent) == "string" then
        ret = ret .. "\n" .. indent
    end
    for key, v in pairs(val) do
        if type(v) == "table" then
            local subindent = false
            if type(indent) == "string" then
                subindent = indent .. "  "
            end

            ret = ret .. key .. " : "
            ret = ret .. PrintValue(v, subindent)
            ret = ret .. " , "
            if type(indent) == "string" then
                ret = ret .. "\n" .. indent
            end
        else
            ret = ret .. key .. " : " .. tostring(v) .. " , "
            if type(indent) == "string" then
                ret = ret .. "\n" .. indent
            end
        end
    end
    ret = ret .. " }"
    if type(indent) == "string" then
        ret = ret .. "\n"
    end
    return ret
end

local function match(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    for key, value in pairs(left) do
        if right[key] == nil then
            return false
        end
        if type(value) == "table" then
            if not match(value, right[key]) then
                return false
            end
        elseif value ~= right[key] then
            return false
        end
    end

    for key, value in pairs(right) do
        if left[key] == nil then
            return false
        end
    end
    return true
end


return {
    match = match,
    PrintValue = PrintValue,
}
