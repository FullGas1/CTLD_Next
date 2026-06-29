---@diagnostic disable
-- ============================================================
-- F-21 : CTLDCrateAssemblyManager._assemble — système complet KUB
-- Module  : M6 (src/CTLD_aasystem.lua)
-- Objectif: Vérifier qu'avec toutes les pièces KUB présentes nearby :
--   1. tryUnpackOrRepair retourne true
--   2. OnAASystemDeployed est publié avec le bon payload
--   3. Le groupe est enregistré dans _completeSystems
--   4. countComplete(BLUE) == 1 après déploiement
--   5. Les crates consommées sont détruites
-- Précondition : un transport BLUE au sol dans la mission.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_aasystem.lua")

ctld_test.start("F-21", "_assemble KUB complet → OnAASystemDeployed")

CTLDCrateAssemblyManager._instance = nil
CTLDCrateManager._instance         = nil
EventDispatcher._instance          = nil
CTLDDCSEventBridge._instance       = nil

local mgr = CTLDCrateAssemblyManager.getInstance()

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

-- Construire des CTLDCrate mockées pour les 2 pièces KUB
-- KUB: "Kub 2P25 ln" (launcher) + "Kub 1S91 str" (radar)
local heliPos = transport:getPoint()
local nearbyPos = { x = heliPos.x + 20, y = heliPos.y, z = heliPos.z + 20 }

-- Mock CTLDCrate minimal (duck-typing: isOnGround, descriptor, position, destroy)
local destroyed = {}
local function makeMockCrate(unitName, pos)
    local c = {
        descriptor = { unit = unitName, cratesRequired = 1 },
        position   = pos or nearbyPos,
        _destroyed = false,
    }
    function c:isOnGround() return true end
    function c:destroy()
        self._destroyed = true
        table.insert(destroyed, unitName)
    end
    function c:isLoaded() return false end
    return c
end

local crateLauncher = makeMockCrate("Kub 2P25 ln")
local crateRadar    = makeMockCrate("Kub 1S91 str")

-- allCrates table (name → crate)
local allCrates = {
    kub_launcher = crateLauncher,
    kub_radar    = crateRadar,
}

-- Capturer OnAASystemDeployed
local deployedPayload = nil
EventDispatcher.getInstance():subscribe("OnAASystemDeployed", function(p)
    deployedPayload = p
end)

-- Exécuter tryUnpackOrRepair avec la crate launcher
local result = false
local okAssemble = pcall(function()
    result = mgr:tryUnpackOrRepair(transport, crateLauncher, allCrates, 500)
end)

ctld_test.assert(okAssemble, "tryUnpackOrRepair ne crash pas")
ctld_test.assert(result == true, "tryUnpackOrRepair retourne true pour crate AA")

-- Event OnAASystemDeployed
ctld_test.assertNotNil(deployedPayload, "OnAASystemDeployed publié")

if deployedPayload then
    ctld_test.assertEqual(deployedPayload.systemName, "KUB AA System",
        "payload.systemName == 'KUB AA System'")
    ctld_test.assertNotNil(deployedPayload.groupName,  "payload.groupName non-nil")
    ctld_test.assertNotNil(deployedPayload.position,   "payload.position non-nil")
    ctld_test.assertEqual(deployedPayload.coalition, coalition.side.BLUE,
        "payload.coalition == BLUE")
    ctld_test.assertNotNil(deployedPayload.timestamp,  "payload.timestamp non-nil")
end

-- countComplete(BLUE) == 1
local completeCnt = mgr:countComplete(coalition.side.BLUE)
ctld_test.assertEqual(completeCnt, 1, "countComplete(BLUE) == 1 après déploiement")

-- _completeSystems contient 1 entrée
local sysCount = 0
for _ in pairs(mgr._completeSystems) do sysCount = sysCount + 1 end
ctld_test.assertEqual(sysCount, 1, "_completeSystems contient 1 entrée")

-- Les crates ont été détruites (les 2 pièces KUB n'ont pas NoCrate)
ctld_test.assert(#destroyed >= 1, "au moins 1 crate détruite après assemblage")

ctld_test.finish()
