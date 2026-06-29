---@diagnostic disable
local unit = Unit.getByName("uh1-1")

local before = unit:getCargosOnBoard()
local cargo = before[1]
local msg = "BEFORE: count=" .. #before .. " name=" .. tostring(cargo and cargo:getName()) .. "\n"
cargo:destroy()
msg = msg .. "destroy() appelé\n"
trigger.action.outText(msg, 40)

-- Vérification à chaque frame suivant pendant 3 secondes
local t0 = timer.getTime()
timer.scheduleFunction(function(_, t)
    local after = unit:getCargosOnBoard()
    local elapsed = string.format("%.3f", t - t0)
    local line = "t+" .. elapsed .. "s : count=" .. #after
    for i, c in pairs(after) do
        local ok, name = pcall(function() return c:getName() end)
        local ok2, ex  = pcall(function() return c:isExist() end)
        line = line .. " [" .. i .. "]name=" .. (ok and tostring(name) or "ERR")
                    .. " isExist=" .. (ok2 and tostring(ex) or "ERR")
    end
    trigger.action.outText(line, 20)
    if t - t0 < 3 then return t + 0.5 end
end, nil, timer.getTime() + 0.1)
