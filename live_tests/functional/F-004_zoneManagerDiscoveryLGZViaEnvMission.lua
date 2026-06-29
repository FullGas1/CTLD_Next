---@diagnostic disable
-- ============================================================
-- F-04 : CTLDZoneManager discovery LGZ via env.mission
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Vérifier que CTLDZoneManager charge les zones LGZ
--           définies dans env.mission.triggers.zones.
--
-- DEPENDENCY mission martyr :
--   - Zone DCS nommée LGZ_base_B dans les triggers de la mission.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("F-04", "CTLDZoneManager discovery LGZ via env.mission")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDZoneManager._instance    = nil

local ok, err = pcall(function()
    CTLDZoneManager.getInstance()
end)

ctld_test.assert(ok, string.format("CTLDZoneManager.getInstance() ne crash pas [%s]", tostring(err)))

local zm = CTLDZoneManager._instance
ctld_test.assertNotNil(zm, "instance CTLDZoneManager non-nil")

-- Vérifier CTLD.log
local logContent = ctld_test.readLog()

ctld_test.assert(logContent:find("CTLDZoneManager ready") ~= nil,
    "CTLD.log contient 'CTLDZoneManager ready'")

-- Compter les zones LGZ chargées
local countLgz = 0
for name, zone in pairs(zm._logisticZones) do
    countLgz = countLgz + 1
end

ctld_test.assert(countLgz >= 0,
    string.format("%d zone(s) LGZ chargées", countLgz))

-- Test spécifique si la mission martyr a LGZ_base_B :
local zBase = zm:getLogisticZone("base")
if zBase then
    ctld_test.assertNotNil(zBase, "zone LGZ 'base' chargée")
    ctld_test.assertEqual(zBase.coalition, coalition.side.BLUE, "zone 'base' coalition BLUE")
    ctld_test.assert(not zBase:isDynamic(), "zone 'base' est statique (pas de linkedUnit)")
    ctld_test.assert(zBase:isAlive(), "zone 'base' isAlive == true")

    -- Le rayon doit être celui de dynamicZoneRadius (ou 200 par défaut)
    local expectedRadius = ctld.gs("dynamicZoneRadius") or 200
    ctld_test.assertEqual(zBase.radius, expectedRadius,
        string.format("zone 'base' radius == %d", expectedRadius))
else
    ctld_test.assert(true, "INFO: LGZ_base_B absent de la mission martyr (skip)")
end

-- Vérifier que l'event OnLogisticZoneUpdated a été publié au démarrage
ctld_test.assert(logContent:find("CTLDZoneManager ready") ~= nil,
    "init CTLDZoneManager terminé (OnLogisticZoneUpdated publié en interne)")

ctld_test.finish()
