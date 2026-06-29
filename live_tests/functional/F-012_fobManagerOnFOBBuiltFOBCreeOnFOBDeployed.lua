---@diagnostic disable
-- ============================================================
-- F-12 : CTLDFOBManager._onFOBBuilt → FOB créé + OnFOBDeployed
-- Module  : M4 (src/CTLD_fob.lua)
-- Objectif: Vérifier que la callback post-scène :
--   - Enregistre le FOB dans _fobs avec le bon fobId / coalition
--   - Popule _objectToFOB (reverse lookup)
--   - Appelle CTLDZoneManager.registerFOBAsLogistic
--   - Publie OnFOBDeployed avec payload complet
--
-- Stratégie : on appelle _onFOBBuilt directement avec une scène
-- mockée, en contournant le timer async de unpackFOBCrates.
-- Le transport fictif (nom inconnu) fait skiper le dropBeacon.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

-- Stubs pour les dépendances non chargées
if not CTLDCrateManager then
    CTLDCrateManager = { getInstance = function() return {} end }
end
if not CTLDSceneManager then
    CTLDSceneManager = { getInstance = function() return {} end }
end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_fob.lua")

ctld_test.start("F-12", "CTLDFOBManager _onFOBBuilt → FOB créé + OnFOBDeployed")

-- Reset singletons
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDZoneManager._instance    = nil
CTLDFOBManager._instance     = nil

-- Stubs objets DCS scène (isExist + getName)
local obj1 = { isExist = function() return true end, getName = function() return "fob_f12_obj_1" end }
local obj2 = { isExist = function() return true end, getName = function() return "fob_f12_obj_2" end }
local mockScene = { _spawnedObjs = { obj1, obj2 } }

local fm = CTLDFOBManager.getInstance()
ctld_test.assert(fm ~= nil, "CTLDFOBManager init OK")

-- Capturer OnFOBDeployed
local deployedPayload = nil
EventDispatcher.getInstance():subscribe("OnFOBDeployed", function(p)
    deployedPayload = p
end)

-- Position fictive (hors de toute zone existante)
local pos = { x = 50000, y = 10, z = 50000 }

-- Appel direct de _onFOBBuilt (simulate post-scène)
local cratesUsed = {
    { crateName = "crate_a", descriptor = { unit = "FOB" } },
}
local ok = pcall(function()
    fm:_onFOBBuilt(mockScene, "ghost_transport_F12", "TestPilot", pos, 2, 2, cratesUsed)
end)

ctld_test.assert(ok, "_onFOBBuilt ne crash pas")

-- OnFOBDeployed publié
ctld_test.assertNotNil(deployedPayload, "OnFOBDeployed publié")

if deployedPayload then
    ctld_test.assertNotNil(deployedPayload.fob,        "payload.fob présent")
    ctld_test.assertNotNil(deployedPayload.fob.fobId,  "payload.fob.fobId présent")
    ctld_test.assertEqual(deployedPayload.fob.coalitionId, 2, "payload coalition == 2 (BLUE)")
    ctld_test.assertEqual(deployedPayload.player, "TestPilot", "payload.player correct")
    ctld_test.assertNotNil(deployedPayload.logisticZone, "payload.logisticZone présent")
    ctld_test.assertEqual(deployedPayload.totalCratesUsed, 1, "totalCratesUsed == 1")
end

-- FOB enregistré dans _fobs
local fobId = deployedPayload and deployedPayload.fob.fobId
ctld_test.assertNotNil(fobId, "fobId extrait du payload")

if fobId then
    local fob = fm._fobs[fobId]
    ctld_test.assertNotNil(fob, "FOB présent dans _fobs[fobId]")

    if fob then
        ctld_test.assertEqual(fob.fobId,       fobId, "fob.fobId cohérent")
        ctld_test.assertEqual(fob.coalitionId, 2,     "fob.coalitionId == 2")
        ctld_test.assert(#fob.sceneObjects == 2,       "fob.sceneObjects contient 2 objets")
    end

    -- Reverse lookup _objectToFOB
    ctld_test.assertEqual(fm._objectToFOB["fob_f12_obj_1"], fobId,
        "reverse lookup obj1 → fobId")
    ctld_test.assertEqual(fm._objectToFOB["fob_f12_obj_2"], fobId,
        "reverse lookup obj2 → fobId")
end

-- Zone logistique enregistrée dans CTLDZoneManager
local zm   = CTLDZoneManager.getInstance()
local zone = zm:getLogisticZoneAtPoint(pos, 2)
ctld_test.assertNotNil(zone, "zone logistique présente dans ZoneManager après déploiement")

ctld_test.finish()
