---@diagnostic disable
local unit = Unit.getByName("uh1-1")
local cargosOnBoard = unit:getCargosOnBoard()
local cargo = cargosOnBoard[1]
local id = cargo.id_

local msg = "id_=" .. tostring(id) .. "\n"

-- Le wrapper table cargo est déjà un objet DCS utilisable ?
msg = msg .. "cargo:getName()=" .. tostring(cargo:getName()) .. "\n"

-- Tenter de reconstruire depuis id_
local tries = {
    ["StaticObject.getByID"]  = function() return StaticObject.getByID(id) end,
    ["Unit.getByID"]          = function() return Unit.getByID(id) end,
    ["Object.getByID"]        = function() return Object.getByID(id) end,
    ["World.getObjectById"]   = function() return World.getObjectById(id) end,
    ["StaticObject {id_}"]    = function() return setmetatable({id_=id}, getmetatable(cargo)) end,
}

for label, fn in pairs(tries) do
    local ok, res = pcall(fn)
    if ok and res then
        local ok2, name = pcall(function() return res:getName() end)
        msg = msg .. label .. " -> " .. (ok2 and tostring(name) or "ERR:" .. tostring(name):sub(1,40)) .. "\n"
    else
        msg = msg .. label .. " -> " .. (ok and "nil" or "ERR") .. "\n"
    end
end

trigger.action.outText(msg, 40)
return msg
