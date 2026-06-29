---@diagnostic disable
local unit = Unit.getByName("uh1-1")
local msg = ""

local before = unit:getCargosOnBoard()
msg = msg .. "BEFORE destroy: count=" .. #before .. "\n"
for i, c in pairs(before) do
    msg = msg .. "  [" .. i .. "] " .. tostring(c:getName()) .. "\n"
end

-- Destroy first cargo
local cargo = before[1]
if cargo then
    cargo:destroy()
    msg = msg .. "destroy() appelé sur " .. tostring(cargo:getName()) .. "\n"
else
    msg = msg .. "aucun cargo à bord\n"
end

-- Check after
local after = unit:getCargosOnBoard()
msg = msg .. "AFTER destroy: count=" .. #after .. "\n"
for i, c in pairs(after) do
    local ok, name = pcall(function() return c:getName() end)
    msg = msg .. "  [" .. i .. "] " .. (ok and tostring(name) or "ERR") .. "\n"
end

trigger.action.outText(msg, 40)
return msg
