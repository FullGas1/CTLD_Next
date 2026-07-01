---@diagnostic disable
-- ============================================================
-- U-38 : CTLDTroopManager._transportLimit
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("U-38", "CTLDTroopManager._transportLimit")

CTLDConfig.get().settings["loadableGroups"] = {}

-- Default (numberOfTroops)
CTLDConfig.get().settings["numberOfTroops"]      = 10
CTLDConfig.get().settings["transportLimitByType"] = nil

local mgr = CTLDTroopManager.getInstance():init()

ctld_test.assertEqual(mgr:_transportLimit("UH-1H"),          10, "default fallback == 10")
ctld_test.assertEqual(mgr:_transportLimit("Mi-8MT"),         10, "Mi-8 fallback == 10")
ctld_test.assertEqual(mgr:_transportLimit("ANY_AIRCRAFT"),   10, "any type fallback == 10")

-- By-type override
CTLDConfig.get().settings["transportLimitByType"] = {
    ["UH-1H"]      = 8,
    ["CH-47D"]     = 20,
    ["Mi-26"]      = 30,
}

ctld_test.assertEqual(mgr:_transportLimit("UH-1H"),   8,  "UH-1H override == 8")
ctld_test.assertEqual(mgr:_transportLimit("CH-47D"),  20, "CH-47D override == 20")
ctld_test.assertEqual(mgr:_transportLimit("Mi-26"),   30, "Mi-26 override == 30")
ctld_test.assertEqual(mgr:_transportLimit("Mi-8MT"),  10, "Mi-8 sans override → fallback 10")

-- numberOfTroops fallback changed
CTLDConfig.get().settings["numberOfTroops"] = 6
ctld_test.assertEqual(mgr:_transportLimit("Unknown"), 6, "fallback suit numberOfTroops modifié")

ctld_test.finish()
