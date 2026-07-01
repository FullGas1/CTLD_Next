---@diagnostic disable
-- ============================================================
-- F-22 : CTLDCrateAssemblyManager._assemble — pièces manquantes
-- Module  : M6 (src/CTLD_aasystem.lua)
-- Objectif: Vérifier que sans toutes les pièces :
--   1. tryUnpackOrRepair retourne true (c'est un AA system)
--   2. OnAASystemDeployed N'est PAS publié
--   3. _completeSystems reste vide
--   4. Les crates ne sont PAS détruites
-- Précondition : un transport BLUE au sol.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_aasystem.lua")

ctld_test.start("F-22", "_assemble KUB incomplet → pas de déploiement")

CTLDCrateAssemblyManager._instance = nil
CTLDCrateManager._instance         = nil
EventDispatcher._instance          = nil
CTLDDCSEventBridge._instance       = nil

local mgr = CTLDCrateAssemblyManager.getInstance()

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local heliPos  = transport:getPoint()
local nearbyPos = { x = heliPos.x + 20, y = heliPos.y, z = heliPos.z + 20 }

-- Seulement le launcher KUB, radar manquant
local destroyed = {}
local crateLauncher = {
    descriptor = { unit = "Kub 2P25 ln", cratesRequired = 1 },
    position   = nearbyPos,
}
function crateLauncher:isOnGround() return true end
function crateLauncher:destroy() table.insert(destroyed, "launcher") end
function crateLauncher:isLoaded() return false end

-- allCrates ne contient que le launcher (radar manquant)
local allCrates = { kub_launcher = crateLauncher }

-- Capturer OnAASystemDeployed
local deployedFired = false
EventDispatcher.getInstance():subscribe("OnAASystemDeployed", function()
    deployedFired = true
end)

local result = false
local ok = pcall(function()
    result = mgr:tryUnpackOrRepair(transport, crateLauncher, allCrates, 500)
end)

ctld_test.assert(ok, "tryUnpackOrRepair ne crash pas (pièces manquantes)")
ctld_test.assert(result == true,
    "tryUnpackOrRepair retourne true (AA reconnu même si incomplet)")

-- Event non publié
ctld_test.assert(not deployedFired, "OnAASystemDeployed NON publié (pièces manquantes)")

-- _completeSystems vide
local sysCount = 0
for _ in pairs(mgr._completeSystems) do sysCount = sysCount + 1 end
ctld_test.assertEqual(sysCount, 0, "_completeSystems reste vide")

-- countComplete == 0
ctld_test.assertEqual(mgr:countComplete(coalition.side.BLUE), 0,
    "countComplete(BLUE) == 0 (rien déployé)")

-- Crates non détruites
ctld_test.assertEqual(#destroyed, 0, "aucune crate détruite sur assemblage incomplet")

ctld_test.finish()
