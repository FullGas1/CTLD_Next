---@diagnostic disable
local FARP_NAME = "DIAG_TEST_FARP_1"
local results = {}

local ab = Airbase.getByName(FARP_NAME)
if not ab then return "Airbase introuvable — spawner d'abord" end

-- État avant destroy
local okE1, e1 = pcall(function() return ab:isExist() end)
results[#results+1] = "avant destroy: ab:isExist()=" .. tostring(e1)

-- Appel destroy
local okD, errD = pcall(function() ab:destroy() end)
results[#results+1] = "destroy() ok=" .. tostring(okD) .. " err=" .. tostring(errD)

-- État après destroy sur la MÊME référence ab
local okE2, e2 = pcall(function() return ab:isExist() end)
results[#results+1] = "après destroy: ab:isExist()=" .. tostring(e2) .. " (pcall ok=" .. tostring(okE2) .. ")"

-- Nouvelle référence via getByName
local ab2 = Airbase.getByName(FARP_NAME)
results[#results+1] = "Airbase.getByName après destroy → " .. tostring(ab2 ~= nil)
if ab2 then
    local okE3, e3 = pcall(function() return ab2:isExist() end)
    results[#results+1] = "ab2:isExist()=" .. tostring(e3)
end

-- Static encore trouvable ?
local s = StaticObject.getByName(FARP_NAME)
results[#results+1] = "StaticObject.getByName → " .. tostring(s ~= nil)
if s then
    local okE4, e4 = pcall(function() return s:isExist() end)
    results[#results+1] = "static:isExist()=" .. tostring(e4)
end

local msg = table.concat(results, " | ")
trigger.action.outText(msg, 40)
return msg
