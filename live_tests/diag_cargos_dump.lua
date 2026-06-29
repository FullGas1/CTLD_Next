---@diagnostic disable
local unit = Unit.getByName("uh1-1")
if not unit then return "unit not found" end

local cargosOnBoard = unit:getCargosOnBoard()
local msg = "[DIAG getCargosOnBoard] type=" .. type(cargosOnBoard) .. "\n"

if type(cargosOnBoard) ~= "table" then
    trigger.action.outText(msg, 20)
    return msg
end

-- Dump index 1 keys/values
for index, cargo in pairs(cargosOnBoard) do
    msg = msg .. "entry[" .. tostring(index) .. "] type=" .. type(cargo) .. "\n"
    if type(cargo) == "table" then
        for k, v in pairs(cargo) do
            msg = msg .. "  ." .. tostring(k) .. " = " .. tostring(v) .. "\n"
        end
    elseif type(cargo) == "userdata" then
        -- Try common DCS Object methods
        local methods = {"getName","getTypeName","getMass","getWeight","getPoint","isExist","getCategory","getDesc","getID"}
        for _, m in ipairs(methods) do
            local ok, val = pcall(function() return cargo[m](cargo) end)
            msg = msg .. "  :" .. m .. "() = " .. (ok and tostring(val) or "ERR:" .. tostring(val):sub(1,40)) .. "\n"
        end
    end
end

trigger.action.outText(msg, 40)
return msg
