---@diagnostic disable
-- ============================================================
-- F-10 : CTLDReconManager hideScan → marks supprimés + OnReconHideTargets
-- Module  : M3 (src/CTLD_recon.lua)
-- Objectif: Vérifier que hideScan() :
--   1. Supprime le scan actif de _activeScans
--   2. Appelle removeIcon sur chaque cible
--   3. Publie OnReconHideTargets avec marksRemoved
--
-- On injecte un scan fictif directement dans _activeScans pour
-- s'affranchir de la dépendance sur _scanLOS (requiert DCS actif).
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_recon.lua")

ctld_test.start("F-10", "CTLDReconManager hideScan — marks supprimés + OnReconHideTargets")

CTLDConfig.get().settings["reconEnabled"] = true

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDReconManager._instance   = nil

local ok = pcall(function() CTLDReconManager.getInstance() end)
ctld_test.assert(ok, "CTLDReconManager init OK")
local rm = CTLDReconManager._instance

-- Récupérer un transport BLUE
local transport = nil
local blueUnits = coalition.getPlayers(coalition.side.BLUE) or {}
if #blueUnits > 0 then transport = blueUnits[1] end

if not transport then
    ctld_test.assert(false, "ECHEC SETUP : aucun transport BLUE")
    ctld_test.finish()
    return
end

local playerName = transport:getPlayerName() or "TestPlayer"

-- Stub trigger.action.removeMark pour compter les suppressions
local removedMarkIds = {}
local origRemoveMark = trigger.action.removeMark
trigger.action.removeMark = function(markId)
    removedMarkIds[#removedMarkIds + 1] = markId
end

-- Injecter un scan fictif avec 2 cibles (markId 10 et 20)
local fakeScan = {
    playerUnit   = transport,
    coalition    = 2,
    autoRefresh  = false,
    refreshTimer = nil,
    targets      = {
        {
            unitType = "Infantry M4", layer = { layerId="infantry", name="Infantry" },
            position = { x=0,y=0,z=0 }, markId = 10,
        },
        {
            unitType = "T-72B", layer = { layerId="ground_vehicles", name="Ground Vehicles" },
            position = { x=100,y=0,z=0 }, markId = 20,
        },
    },
}
rm._activeScans[playerName] = fakeScan

-- Capturer OnReconHideTargets
local hidePayload = nil
EventDispatcher.getInstance():subscribe("OnReconHideTargets", function(p)
    hidePayload = p
end)

-- Exécuter hideScan
local okHide = pcall(function()
    rm:hideScan(transport, playerName)
end)
ctld_test.assert(okHide, "hideScan ne crash pas")

-- Scan supprimé de _activeScans
ctld_test.assertNil(rm._activeScans[playerName],
    "_activeScans[player] == nil après hideScan")

-- removeMark appelé 3 fois par cible (markId*10+1, *10+2, *10+3)
-- Pour 2 cibles (markId 10 et 20) = 6 appels
ctld_test.assertEqual(#removedMarkIds, 6,
    "removeMark appelé 6 fois (3 sub-marks × 2 cibles)")

-- Event publié
ctld_test.assertNotNil(hidePayload, "OnReconHideTargets publié")
if hidePayload then
    ctld_test.assertEqual(hidePayload.player, playerName, "payload.player correct")
    ctld_test.assertEqual(hidePayload.totalMarksRemoved, 2, "totalMarksRemoved == 2")
    ctld_test.assert(type(hidePayload.marksRemoved) == "table",
        "payload.marksRemoved est une table")
end

-- Restaurer removeMark
trigger.action.removeMark = origRemoveMark

ctld_test.finish()
