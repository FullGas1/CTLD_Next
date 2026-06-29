---@diagnostic disable
-- ============================================================
-- F-05 : CTLDZoneManager onDead → suppression zone dynamique + OnLogisticZoneUpdated
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Vérifier que quand une S_EVENT_DEAD est simulée sur une
--           unité liée à une CTLDLogisticZone dynamique :
--           1. La zone est retirée de _logisticZones
--           2. OnLogisticZoneUpdated est publié avec unitsRemoved
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("F-05", "CTLDZoneManager onDead → suppression zone dynamique + OnLogisticZoneUpdated")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDZoneManager._instance    = nil

-- Initialiser le ZoneManager sans erreur
local ok, err = pcall(function() CTLDZoneManager.getInstance() end)
ctld_test.assert(ok, string.format("ZoneManager init OK [%s]", tostring(err)))

local zm = CTLDZoneManager._instance

-- Créer une unité fictive (linked unit)
local fakeUnitAlive = true
local fakeUnit = {
    getName    = function() return "logistic_truck_1" end,
    isExist    = function() return fakeUnitAlive end,
    getPoint   = function() return { x=1000, y=0, z=2000 } end,
    getCoalition = function() return 2 end,
}

-- Injecter manuellement une zone dynamique liée à fakeUnit
local dynZone = CTLDLogisticZone:new({
    name       = "logistic_truck_1",
    coalition  = 2,
    center     = { x=1000, y=0, z=2000 },
    radius     = 300,
    linkedUnit = fakeUnit,
    active     = true,
})
zm._logisticZones["logistic_truck_1"] = dynZone

ctld_test.assert(zm:getLogisticZone("logistic_truck_1") ~= nil,
    "zone dynamique injectée présente dans _logisticZones")

-- Souscrire à OnLogisticZoneUpdated pour capturer l'event
local eventPayload = nil
EventDispatcher.getInstance():subscribe("OnLogisticZoneUpdated", function(payload)
    eventPayload = payload
end)

-- Simuler la mort de l'unité
fakeUnitAlive = false
local fakeDeadEvent = {
    id        = world.event.S_EVENT_DEAD,
    initiator = fakeUnit,
}
zm:onDead(fakeDeadEvent)

-- Vérifications
ctld_test.assertNil(zm:getLogisticZone("logistic_truck_1"),
    "zone dynamique retirée de _logisticZones après onDead")

ctld_test.assertNotNil(eventPayload,
    "OnLogisticZoneUpdated publié après suppression")

if eventPayload then
    ctld_test.assert(type(eventPayload.unitsRemoved) == "table",
        "payload.unitsRemoved est une table")
    ctld_test.assert(#eventPayload.unitsRemoved >= 1,
        "payload.unitsRemoved contient au moins 1 entrée")
    if #eventPayload.unitsRemoved >= 1 then
        ctld_test.assertEqual(eventPayload.unitsRemoved[1].unitName, "logistic_truck_1",
            "unitsRemoved[1].unitName == 'logistic_truck_1'")
    end
end

-- Vérifier que onDead sur unité inconnue ne crash pas
local fakeUnknown = {
    getName  = function() return "unit_not_a_zone" end,
    isExist  = function() return false end,
}
local ok2 = pcall(function()
    zm:onDead({ id = world.event.S_EVENT_DEAD, initiator = fakeUnknown })
end)
ctld_test.assert(ok2, "onDead sur unité non liée à une zone ne crash pas")

ctld_test.finish()
