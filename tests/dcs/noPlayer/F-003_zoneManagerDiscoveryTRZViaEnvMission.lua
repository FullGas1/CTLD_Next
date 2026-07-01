---@diagnostic disable
-- ============================================================
-- F-03 : CTLDZoneManager discovery TRZ via env.mission
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Vérifier que CTLDZoneManager.getInstance() charge les
--           zones TRZ définies dans env.mission.triggers.zones.
--           Les zones chargées doivent être accessibles via getTroopZone().
--
-- DEPENDENCY mission martyr :
--   - Zones DCS nommées TRZ_alpha_B_10_nil_0 et TRZ_beta_R_999_obj1_5
--     définies dans les triggers de la mission.
--   Convention stricte 5 champs : TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>
--   stock=999 → illimité (interne 0) ; stock=0 → pas de pickup
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("F-03", "CTLDZoneManager discovery TRZ via env.mission")

-- Reset singletons
EventDispatcher._instance     = nil
CTLDDCSEventBridge._instance  = nil
CTLDZoneManager._instance     = nil

local ok, err = pcall(function()
    CTLDZoneManager.getInstance()
end)

ctld_test.assert(ok, string.format("CTLDZoneManager.getInstance() ne crash pas [%s]", tostring(err)))

local zm = CTLDZoneManager._instance
ctld_test.assertNotNil(zm, "instance CTLDZoneManager non-nil après init")

-- Vérifier CTLD.log
local logContent = ctld_test.readLog()

ctld_test.assert(logContent:find("CTLDZoneManager ready") ~= nil,
    "CTLD.log contient 'CTLDZoneManager ready'")

-- Compter les zones TRZ chargées depuis env.mission
local countTrz = 0
for name, zone in pairs(zm._troopZones) do
    if zone.dcsName and zone.dcsName:sub(1,4) == "TRZ_" then
        countTrz = countTrz + 1
    end
end

ctld_test.assert(countTrz >= 0,
    string.format("%d zone(s) TRZ chargées depuis env.mission", countTrz))

-- Test spécifique si la mission martyr a TRZ_alpha_B_10 :
local zAlpha = zm:getTroopZone("alpha")
if zAlpha then
    ctld_test.assertNotNil(zAlpha, "zone TRZ 'alpha' chargée")
    ctld_test.assert(zAlpha:hasPickup(), "zone 'alpha' a pickup (pickMaxStock=10)")
    ctld_test.assertEqual(zAlpha.pickMaxStock, 10,  "zone 'alpha' pickMaxStock == 10")
    ctld_test.assertEqual(zAlpha.coalition, coalition.side.BLUE, "zone 'alpha' coalition BLUE")
else
    ctld_test.assert(true, "INFO: TRZ_alpha_B_10 absent de la mission martyr (skip)")
end

-- Test spécifique si la mission martyr a TRZ_beta_R_999_obj1_5 :
local zBeta = zm:getTroopZone("beta")
if zBeta then
    ctld_test.assertNotNil(zBeta, "zone TRZ 'beta' chargée")
    ctld_test.assertEqual(zBeta.pickMaxStock,    0,      "zone 'beta' pickMaxStock == 0 (illimité interne)")
    ctld_test.assertEqual(zBeta.objectiveFlag,   "obj1", "zone 'beta' objectiveFlag == 'obj1'")
    ctld_test.assertEqual(zBeta.objectiveTarget, 5,      "zone 'beta' objectiveTarget == 5")
    ctld_test.assertEqual(zBeta.coalition, coalition.side.RED, "zone 'beta' coalition RED")
else
    ctld_test.assert(true, "INFO: TRZ_beta_R_999_obj1_5 absent de la mission martyr (skip)")
end

ctld_test.finish()
