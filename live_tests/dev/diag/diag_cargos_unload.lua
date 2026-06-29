---@diagnostic disable
local unit = Unit.getByName("uh1-1")
local msg = ""

-- Tenter différentes variantes de méthode unload
local methods = {
    "UnloadCargo", "unloadCargo", "ReleaseCargo", "releaseCargo",
    "DropCargo", "dropCargo", "clearCargos", "ClearCargos",
}
for _, m in ipairs(methods) do
    local ok, res = pcall(function() return unit[m](unit) end)
    msg = msg .. m .. " -> " .. (ok and tostring(res) or "ERR") .. "\n"
end

-- Vérif état slot après
local after = unit:getCargosOnBoard()
msg = msg .. "getCargosOnBoard count=" .. #after .. "\n"

trigger.action.outText(msg, 30)
return msg
