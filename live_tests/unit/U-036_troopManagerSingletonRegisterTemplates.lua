---@diagnostic disable
-- ============================================================
-- U-36 : CTLDTroopManager singleton + _registerTemplates
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")

-- Stub CTLDPlayerManager for unit isolation (menu registration not under test here)
CTLDPlayerManager = CTLDPlayerManager or {}
CTLDPlayerManager.getInstance = CTLDPlayerManager.getInstance or function()
    return { registerMenuSection = function() end }
end

-- Stub missionCommands (used by buildMenu during init path)
missionCommands = missionCommands or {
    addSubMenuForGroup  = function() return {} end,
    addCommandForGroup  = function() end,
    removeItemForGroup  = function() end,
}

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("U-36", "CTLDTroopManager singleton + _registerTemplates")

-- Reset singleton
_G["_instance"] = nil   -- module-local, force via re-dofile if needed

-- Inject loadableGroups config
CTLDConfig.get().settings["loadableGroups"] = {
    { name = "Alpha Squad", inf = 3, mg = 1, at = 0, aa = 0, mortar = 0, jtac = 0 },
    { name = "Bravo JTAC",  inf = 2, mg = 0, at = 0, aa = 0, mortar = 0, jtac = 1 },
}

local mgr1 = CTLDTroopManager.getInstance():init()
ctld_test.assertNotNil(mgr1, "getInstance() retourne une instance")

local mgr2 = CTLDTroopManager.getInstance()
ctld_test.assert(mgr1 == mgr2, "getInstance() idempotent")

-- _templateCount == 2
ctld_test.assertEqual(mgr1._templateCount, 2, "_templateCount == 2")

-- Each template got _dbKey and total set
local templates = CTLDConfig.get().settings["loadableGroups"]

local t1 = templates[1]
ctld_test.assertNotNil(t1._dbKey, "template[1]._dbKey set")
ctld_test.assertEqual(t1.total, 4, "template[1].total == 4 (3 inf + 1 mg)")
ctld_test.assert(not t1.hasJtac, "template[1].hasJtac == false")

local t2 = templates[2]
ctld_test.assertNotNil(t2._dbKey, "template[2]._dbKey set")
ctld_test.assertEqual(t2.total, 3, "template[2].total == 3 (2 inf + 1 jtac)")
ctld_test.assert(t2.hasJtac, "template[2].hasJtac == true")

-- Entries inserted in CTLDObjectRegistry._db
ctld_test.assertNotNil(CTLDObjectRegistry._db[t1._dbKey], "db entry créée pour template[1]")
ctld_test.assertNotNil(CTLDObjectRegistry._db[t2._dbKey], "db entry créée pour template[2]")

local entry1 = CTLDObjectRegistry._db[t1._dbKey]
ctld_test.assertEqual(entry1.groupType, "GROUND", "groupType == GROUND")
ctld_test.assertNotNil(entry1.units,    "units array présent")
ctld_test.assertEqual(#entry1.units, 4, "units array has 4 entries (3 inf + 1 mg)")

local entry2 = CTLDObjectRegistry._db[t2._dbKey]
ctld_test.assertEqual(#entry2.units, 3, "units array has 3 entries (2 inf + 1 jtac)")

-- _inTransit and _droppedGroups initialized
ctld_test.assertNotNil(mgr1._inTransit,     "_inTransit table présente")
ctld_test.assertNotNil(mgr1._droppedGroups, "_droppedGroups table présente")

ctld_test.finish()
