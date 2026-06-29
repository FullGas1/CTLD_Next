---@diagnostic disable
-- ============================================================
-- F-14 : CTLDFOBManager → CTLDZoneManager.registerFOBAsLogistic
-- Module  : M4 (src/CTLD_fob.lua + src/CTLD_zone.lua)
-- Objectif: Vérifier l'intégration FOBManager → ZoneManager :
--   - registerFOBAsLogistic crée une zone logistique accessible via
--     getLogisticZoneAtPoint et getLogisticZonesForCoalition
--   - unregisterLogistic supprime la zone
--   - Les deux opérations publient OnLogisticZoneUpdated avec
--     les champs added/removed corrects
--
-- Ce cas teste l'API ZoneManager en isolation (appels directs,
-- sans passer par unpackFOBCrates ou la scène).
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("F-14", "CTLDZoneManager registerFOBAsLogistic / unregisterLogistic")

-- Reset singletons
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDZoneManager._instance    = nil

local zm = CTLDZoneManager.getInstance()
ctld_test.assert(zm ~= nil, "CTLDZoneManager init OK")

-- Capturer OnLogisticZoneUpdated
local updatedPayloads = {}
EventDispatcher.getInstance():subscribe("OnLogisticZoneUpdated", function(p)
    updatedPayloads[#updatedPayloads + 1] = p
end)

-- ---- Registre initial : pas de zone FOB ----
local fobName = "Deployed FOB F14"
local fobPos  = { x = 70000, y = 10, z = 70000 }
local radius  = 200
local coal    = 2

ctld_test.assertNil(zm:getLogisticZoneAtPoint(fobPos, coal),
    "aucune zone avant registerFOBAsLogistic")

-- Vider les events de l'init (OnLogisticZoneUpdated publié par init)
updatedPayloads = {}

-- ---- registerFOBAsLogistic ----
local okReg = pcall(function()
    zm:registerFOBAsLogistic(fobName, fobPos, radius, coal)
end)
ctld_test.assert(okReg, "registerFOBAsLogistic ne crash pas")

-- Zone accessible via getLogisticZoneAtPoint
local zone = zm:getLogisticZoneAtPoint(fobPos, coal)
ctld_test.assertNotNil(zone, "zone logistique présente après registerFOBAsLogistic")

if zone then
    ctld_test.assert(zone:isInZone(fobPos), "le centre est dans la zone")
    -- Point légèrement à l'extérieur (radius+10)
    local outside = { x = fobPos.x + radius + 10, y = fobPos.y, z = fobPos.z }
    ctld_test.assert(not zone:isInZone(outside),
        "point à r+10 m est hors de la zone")
end

-- Zone présente dans getLogisticZonesForCoalition
local zones = zm:getLogisticZonesForCoalition(coal)
local found = false
for _, z in ipairs(zones) do
    if z.name == fobName then found = true end
end
ctld_test.assert(found, "zone présente dans getLogisticZonesForCoalition(BLUE)")

-- Pas visible pour coalition adverse
local zonesRed = zm:getLogisticZonesForCoalition(1)
local foundRed = false
for _, z in ipairs(zonesRed) do
    if z.name == fobName then foundRed = true end
end
ctld_test.assert(not foundRed, "zone absente pour coalition RED")

-- OnLogisticZoneUpdated publié lors du register
ctld_test.assert(#updatedPayloads >= 1, "OnLogisticZoneUpdated publié après register")
local regEvent = updatedPayloads[#updatedPayloads]
if regEvent then
    ctld_test.assert(regEvent.unitsAdded ~= nil, "payload.added présent")
    ctld_test.assert(#regEvent.unitsAdded >= 1, "payload.added non vide")
    if #regEvent.unitsAdded >= 1 then
        ctld_test.assertEqual(regEvent.unitsAdded[1].unitName, fobName,
            "added[1].unitName == fobName")
    end
end

-- ---- unregisterLogistic ----
updatedPayloads = {}
local okUnreg = pcall(function()
    zm:unregisterLogistic(fobName)
end)
ctld_test.assert(okUnreg, "unregisterLogistic ne crash pas")

-- Zone plus accessible
ctld_test.assertNil(zm:getLogisticZoneAtPoint(fobPos, coal),
    "zone absente après unregisterLogistic")

-- Plus dans getLogisticZonesForCoalition
local zonesAfter = zm:getLogisticZonesForCoalition(coal)
local foundAfter = false
for _, z in ipairs(zonesAfter) do
    if z.name == fobName then foundAfter = true end
end
ctld_test.assert(not foundAfter, "zone retirée de getLogisticZonesForCoalition après unregister")

-- OnLogisticZoneUpdated publié lors du désenregistrement
ctld_test.assert(#updatedPayloads >= 1, "OnLogisticZoneUpdated publié après unregister")
local unregEvent = updatedPayloads[#updatedPayloads]
if unregEvent then
    ctld_test.assert(unregEvent.unitsRemoved ~= nil, "payload.removed présent")
    ctld_test.assert(#unregEvent.unitsRemoved >= 1, "payload.removed non vide")
    if #unregEvent.unitsRemoved >= 1 then
        ctld_test.assertEqual(unregEvent.unitsRemoved[1].unitName, fobName,
            "removed[1].unitName == fobName")
    end
end

-- ---- unregisterLogistic idempotent (zone inexistante) ----
local okUnregAgain = pcall(function()
    zm:unregisterLogistic(fobName)
end)
ctld_test.assert(okUnregAgain, "unregisterLogistic sur zone inexistante ne crash pas")

ctld_test.finish()
