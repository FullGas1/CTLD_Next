---@diagnostic disable
local ok, err = pcall(function()
    local unit = Unit.getByName("uh1-1")
    if not unit then trigger.action.outText("unit nil", 20); return end

    local before = unit:getCargosOnBoard()
    local inAir = ctld.utils.inAir(unit)
    local msg = string.format("BEFORE: count=%d inAir=%s\n", #before, tostring(inAir))
    for i, c in pairs(before) do
        msg = msg .. "  [" .. i .. "] " .. tostring(c:getName()) .. "\n"
    end
    trigger.action.outText(msg, 30)

    local cargo = before[1]
    if not cargo then trigger.action.outText("pas de cargo", 20); return end

    local ok2, err2 = pcall(function() unit:disembarking() end)
    trigger.action.outText("disembarking(): ok=" .. tostring(ok2) .. " err=" .. tostring(err2), 30)

    local after = unit:getCargosOnBoard()
    trigger.action.outText("AFTER immédiat: count=" .. #after, 20)

    timer.scheduleFunction(function()
        local later = unit:getCargosOnBoard()
        local m = "AFTER +1s: count=" .. #later .. "\n"
        local st = StaticObject.getByName("cr1-1")
        m = m .. "StaticObject cr1-1=" .. tostring(st) .. "\n"
        if st then
            local ok3, p = pcall(function() return st:getPoint() end)
            if ok3 then m = m .. string.format("  pos y=%.0fm\n", p.y) end
        end
        trigger.action.outText(m, 30)
    end, nil, timer.getTime() + 1)
end)
if not ok then trigger.action.outText("PCALL ERR: " .. tostring(err), 30) end
return ok and "OK" or err
