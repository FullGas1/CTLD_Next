-- Dump raw getCargosOnBoard() response
local groups = coalition.getGroups(coalition.side.BLUE, Group.Category.HELICOPTER)
local unit = nil
for _, grp in ipairs(groups or {}) do
    for _, u in ipairs(grp:getUnits() or {}) do
        if u and u:isExist() and u:isActive() then unit = u; break end
    end
    if unit then break end
end

if not unit then
    trigger.action.outText("[DUMP] No helo found", 8)
    return "no helo"
end

local ok, cargos = pcall(function() return unit:getCargosOnBoard() end)
if not ok then
    trigger.action.outText("[DUMP] getCargosOnBoard ERROR: " .. tostring(cargos), 10)
    return "error: " .. tostring(cargos)
end

if type(cargos) ~= "table" then
    trigger.action.outText("[DUMP] getCargosOnBoard returned: " .. tostring(cargos), 10)
    return tostring(cargos)
end

local lines = { string.format("[DUMP] unit=%s | count=%d", unit:getName(), #cargos) }
for i, cargo in ipairs(cargos) do
    local name, dispName, weight, cat = "?", "?", "?", "?"
    pcall(function() name     = tostring(cargo:getName()) end)
    pcall(function() dispName = tostring(cargo:getCargoDisplayName()) end)
    pcall(function() weight   = tostring(cargo:getCargoWeight()) end)
    pcall(function() cat      = tostring(cargo:getCategory()) end)
    lines[#lines+1] = string.format(
        "  [%d] name=%s | displayName=%s | weight=%s | category=%s",
        i, name, dispName, weight, cat)
end

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 15)
env.info(msg)
return msg
