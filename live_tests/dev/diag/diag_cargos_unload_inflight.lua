---@diagnostic disable
-- Test UnloadCargo() en vol — vérifier libération slot + comportement caisse
local ok, err = pcall(function()
    local unit = Unit.getByName("uh1-1")
    if not unit then trigger.action.outText("unit nil", 20); return end

    local inAir = ctld.utils.inAir(unit)
    local pos = unit:getPoint()

    local before = unit:getCargosOnBoard()
    local msg = string.format("BEFORE: count=%d inAir=%s alt=%.0fm\n",
        #before, tostring(inAir), pos.y)
    for i, c in pairs(before) do
        msg = msg .. "  [" .. i .. "] " .. tostring(c:getName()) .. "\n"
    end
    trigger.action.outText(msg, 30)

    local cargo = before[1]
    if not cargo then trigger.action.outText("pas de cargo à bord", 20); return end

    local ok2, err2 = pcall(function() unit:UnloadCargo(cargo) end)
    trigger.action.outText("UnloadCargo(cargo): ok=" .. tostring(ok2) .. " err=" .. tostring(err2), 30)

    -- Vérif immédiate + à +1s
    local after = unit:getCargosOnBoard()
    trigger.action.outText("AFTER immédiat: count=" .. #after, 20)

    timer.scheduleFunction(function()
        local later = unit:getCargosOnBoard()
        local m = "AFTER +1s: count=" .. #later .. "\n"
        local st = StaticObject.getByName("cr1-1")
        m = m .. "StaticObject cr1-1=" .. tostring(st) .. "\n"
        if st then
            local ok3, p = pcall(function() return st:getPoint() end)
            if ok3 then
                m = m .. string.format("  pos=(%.0f, %.0f, %.0f)\n", p.x, p.y, p.z)
            end
        end
        trigger.action.outText(m, 30)
    end, nil, timer.getTime() + 1)
end)
if not ok then trigger.action.outText("PCALL ERR: " .. tostring(err), 30) end
return ok and "OK" or err
