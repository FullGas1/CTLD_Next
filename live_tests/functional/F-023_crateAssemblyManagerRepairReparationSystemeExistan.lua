---@diagnostic disable
-- ============================================================
-- F-23 : CTLDCrateAssemblyManager._repair — réparation système existant
-- Module  : M6 (src/CTLD_aasystem.lua)
-- Objectif: Vérifier que la réparation d'un système existant :
--   1. tryUnpackOrRepair retourne true (crate repair reconnue)
--   2. OnAASystemRepaired est publié avec le bon payload
--   3. L'ancien groupe est remplacé dans _completeSystems
--   4. La repair crate est détruite
-- Précondition : un transport BLUE au sol.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_aasystem.lua")

ctld_test.start("F-23", "_repair KUB → OnAASystemRepaired")

CTLDCrateAssemblyManager._instance = nil
CTLDCrateManager._instance         = nil
EventDispatcher._instance          = nil
CTLDDCSEventBridge._instance       = nil

local mgr = CTLDCrateAssemblyManager.getInstance()

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local heliPos   = transport:getPoint()
local nearbyPos = { x = heliPos.x + 20, y = heliPos.y, z = heliPos.z + 20 }

-- === STEP 1 : déployer un KUB complet ===
local destroyed1 = {}
local function makeMock(unitName, pos)
    local c = { descriptor = { unit = unitName, cratesRequired = 1 },
                position = pos or nearbyPos }
    function c:isOnGround() return true end
    function c:destroy() table.insert(destroyed1, unitName) end
    function c:isLoaded() return false end
    return c
end

local allCrates = {
    kub_ln  = makeMock("Kub 2P25 ln"),
    kub_str = makeMock("Kub 1S91 str"),
}

local deployedPayload = nil
EventDispatcher.getInstance():subscribe("OnAASystemDeployed", function(p)
    deployedPayload = p
end)

local ok1 = pcall(function()
    mgr:tryUnpackOrRepair(transport, allCrates.kub_ln, allCrates, 500)
end)
ctld_test.assert(ok1, "STEP1: déploiement KUB ne crash pas")
ctld_test.assertNotNil(deployedPayload, "STEP1: OnAASystemDeployed publié")

local sysCount1 = 0
local firstGroupName = nil
for k in pairs(mgr._completeSystems) do sysCount1 = sysCount1 + 1; firstGroupName = k end
ctld_test.assertEqual(sysCount1, 1, "STEP1: 1 système dans _completeSystems")

-- === STEP 2 : réparer avec "KUB Repair" ===
local repairDestroyed = false
local repairCrate = {
    descriptor = { unit = "KUB Repair", cratesRequired = 1 },
    position   = nearbyPos,
}
function repairCrate:isOnGround() return true end
function repairCrate:destroy()    repairDestroyed = true end
function repairCrate:isLoaded()   return false end

local repairedPayload = nil
EventDispatcher.getInstance():subscribe("OnAASystemRepaired", function(p)
    repairedPayload = p
end)

-- Vérifier que getTemplateForUnit trouve KUB via repair
local tmpl = mgr:getTemplateForUnit("KUB Repair")
ctld_test.assertNotNil(tmpl, "getTemplateForUnit('KUB Repair') retourne KUB template")
ctld_test.assertEqual(tmpl.name, "KUB AA System", "KUB Repair → KUB AA System")

local result = false
local ok2 = pcall(function()
    result = mgr:tryUnpackOrRepair(transport, repairCrate, {}, 500)
end)

ctld_test.assert(ok2, "STEP2: tryUnpackOrRepair repair ne crash pas")
ctld_test.assert(result == true, "STEP2: tryUnpackOrRepair retourne true")

-- Event OnAASystemRepaired
ctld_test.assertNotNil(repairedPayload, "OnAASystemRepaired publié")

if repairedPayload then
    ctld_test.assertEqual(repairedPayload.systemName, "KUB AA System",
        "payload.systemName == 'KUB AA System'")
    ctld_test.assertNotNil(repairedPayload.groupName, "payload.groupName non-nil")
    ctld_test.assertEqual(repairedPayload.coalition, coalition.side.BLUE,
        "payload.coalition == BLUE")
    ctld_test.assertNotNil(repairedPayload.timestamp, "payload.timestamp non-nil")
end

-- Repair crate détruite
ctld_test.assert(repairDestroyed, "repair crate détruite")

-- _completeSystems toujours 1 entrée (ancien remplacé par nouveau)
local sysCount2 = 0
for _ in pairs(mgr._completeSystems) do sysCount2 = sysCount2 + 1 end
ctld_test.assertEqual(sysCount2, 1, "_completeSystems toujours 1 entrée après repair")

ctld_test.finish()
