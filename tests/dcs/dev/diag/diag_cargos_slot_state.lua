---@diagnostic disable
local unit = Unit.getByName("uh1-1")

local cargos = unit:getCargosOnBoard()
local msg = "getCargosOnBoard count=" .. #cargos .. "\n"

-- Inspecter les desc de l'appareil pour voir l'état des slots
local ok1, desc = pcall(function() return unit:getDesc() end)
if ok1 and desc then
    local ok2, maxCargo = pcall(function() return desc.maxSlingload end)
    msg = msg .. "desc.maxSlingload=" .. (ok2 and tostring(maxCargo) or "ERR") .. "\n"
end

-- Tenter de trouver cr1-1 comme StaticObject
local st = StaticObject.getByName("cr1-1")
msg = msg .. "StaticObject.getByName(cr1-1)=" .. tostring(st) .. "\n"
if st then
    local ok3, ex = pcall(function() return st:isExist() end)
    msg = msg .. "  isExist=" .. (ok3 and tostring(ex) or "ERR") .. "\n"
end

-- Tenter de trouver cr1-1 comme Unit
local u = Unit.getByName("cr1-1")
msg = msg .. "Unit.getByName(cr1-1)=" .. tostring(u) .. "\n"

trigger.action.outText(msg, 30)
return msg
