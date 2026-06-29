return (function()
    local s = StaticObject.getByName("shooter")
    if not s then return "static 'shooter' not found" end
    local desc = s:getDesc()
    local result = {}
    for k, v in pairs(desc) do
        result[#result+1] = tostring(k) .. "=" .. tostring(v)
    end
    return table.concat(result, " | ")
end)()
