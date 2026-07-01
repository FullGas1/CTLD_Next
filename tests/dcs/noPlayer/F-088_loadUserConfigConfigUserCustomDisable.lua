---@diagnostic disable
-- ============================================================
-- F-88 : _loadUserConfig — ctld_config_user custom + disable
-- Module  : Feature D (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC .. "CTLD_core.lua")
dofile(SRC .. "lib/CTLD_objectRegistry.lua")
dofile(SRC .. "lib/CTLDParachuteEffect.lua")

CTLDPlayerManager = CTLDPlayerManager or {}
CTLDPlayerManager.getInstance = CTLDPlayerManager.getInstance
    or function() return { registerMenuSection = function() end } end
missionCommands = missionCommands or {
    addSubMenuForGroup = function() return {} end,
    addCommandForGroup = function() end,
    removeItemForGroup = function() end,
}

dofile(SRC .. "CTLD_troop.lua")

-- Inject standard templates
CTLDConfig.get().settings["loadableGroups"] = {
    { name = "Standard Group", inf = 6, mg = 2, at = 2 },
    { name = "Mortar Squad",   mortar = 6 },
    { name = "JTAC Group",     inf = 4, jtac = 1 },
}
CTLDConfig.get().settings["numberOfTroops"]    = 10
CTLDConfig.get().settings["transportLimitByType"] = {}

-- Set up ctld_config_user BEFORE init
ctld_config_user = {
    customLoadableGroups = {
        { name = "Recon Team",    composition = { inf = 4, jtac = 1 }, side = 2 },
        { name = "AT Squad",      composition = { inf = 2, at = 6  }, side = 1 },
        { name = "Support Heavy", composition = { inf = 8, mg = 4, aa = 2 } },
    },
    disableLoadableGroups = {
        "Mortar Squad",
        "Standard Group",
    },
}

-- Reset singleton and init
CTLDTroopManager._instance = nil
local mgr = CTLDTroopManager.getInstance()

ctld_test.start("F-88", "_loadUserConfig — customLoadableGroups + disableLoadableGroups")

-- 3 standard + 3 custom = 6 total
ctld_test.assertEqual(#mgr._templates, 6, "6 templates total (3 std + 3 custom)")
ctld_test.assertEqual(mgr._templateCount, 6, "_templateCount == 6")

-- Custom templates created
local r = mgr:_findTemplate("Recon Team")
ctld_test.assertNotNil(r,             "Recon Team created")
ctld_test.assertEqual(r.total, 5,     "Recon Team total=5")
ctld_test.assert(r.custom == true,    "Recon Team: custom=true")
ctld_test.assertEqual(r.side, 2,      "Recon Team: side=2")

local at = mgr:_findTemplate("AT Squad")
ctld_test.assertNotNil(at,            "AT Squad created")
ctld_test.assertEqual(at.total, 8,    "AT Squad total=8")
ctld_test.assertEqual(at.side, 1,     "AT Squad: side=1")

local sh = mgr:_findTemplate("Support Heavy")
ctld_test.assertNotNil(sh,            "Support Heavy created")
ctld_test.assertEqual(sh.total, 14,   "Support Heavy total=14")
ctld_test.assertNil(sh.side,          "Support Heavy: side=nil (both)")

-- Disabled templates
local ms = mgr:_findTemplate("Mortar Squad")
ctld_test.assert(ms.disabled == true, "Mortar Squad disabled by user config")

local sg = mgr:_findTemplate("Standard Group")
ctld_test.assert(sg.disabled == true, "Standard Group disabled by user config")

-- Non-disabled template still active
local jg = mgr:_findTemplate("JTAC Group")
ctld_test.assert(jg.disabled == false, "JTAC Group still enabled")

-- ObjectRegistry entries created for custom templates
ctld_test.assertNotNil(CTLDObjectRegistry._db[r._dbKey],  "Recon Team in ObjectRegistry")
ctld_test.assertNotNil(CTLDObjectRegistry._db[at._dbKey], "AT Squad in ObjectRegistry")
ctld_test.assertNotNil(CTLDObjectRegistry._db[sh._dbKey], "Support Heavy in ObjectRegistry")

ctld_test.finish()
