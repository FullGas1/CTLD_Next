---@diagnostic disable
-- Diag: list all DCS native cargos onboard uh1-1
local unitName = "uh1-1"
local unit = Unit.getByName(unitName)
if not unit then
    trigger.action.outText("[DIAG] unit not found: " .. unitName, 20)
    return "[DIAG] unit not found: " .. unitName
end

local cargosOnBoard = unit:getCargosOnBoard()
local msg = "[DIAG CARGOS ONBOARD] unit=" .. unitName .. "\n"

if not cargosOnBoard or not next(cargosOnBoard) then
    msg = msg .. "  (empty)\n"
else
    for index, cargo in pairs(cargosOnBoard) do
        local ok1, name     = pcall(function() return cargo:getName() end)
        local ok2, typeName = pcall(function() return cargo:getTypeName() end)
        local ok3, mass     = pcall(function() return cargo:getMass() end)
        msg = msg .. string.format("  [%s] name=%s type=%s mass=%s\n",
            tostring(index),
            ok1 and tostring(name)     or "err",
            ok2 and tostring(typeName) or "err",
            ok3 and tostring(mass)     or "err")
    end
end

trigger.action.outText(msg, 30)
return msg
