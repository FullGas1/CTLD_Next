---@diagnostic disable
-- ============================================================
-- U-37 : CTLDTroopManager — hasTroops / getInTransit / getWeight
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("U-37", "CTLDTroopManager — hasTroops / getInTransit / getWeight")

CTLDConfig.get().settings["loadableGroups"] = {}

local mgr = CTLDTroopManager.getInstance():init()

-- Nothing in transit yet
ctld_test.assert(not mgr:hasTroops("heli_1"),   "hasTroops inconnu == false")
ctld_test.assertNil(mgr:getInTransit("heli_1"),  "getInTransit inconnu == nil")
ctld_test.assertEqual(mgr:getWeight("heli_1"), 0, "getWeight inconnu == 0")

-- Inject a troop group
local grp = CTLDTroopGroup:new({
    templateKey  = "k",
    templateName = "Squad A",
    unitTotal    = 4,
    weight       = 436,
    hasJtac      = false,
    coalitionId  = coalition.side.BLUE,
    countryId    = 2,
})
mgr._inTransit["heli_1"] = grp

ctld_test.assert(mgr:hasTroops("heli_1"),         "hasTroops == true après injection")
ctld_test.assertEqual(mgr:getInTransit("heli_1"), grp, "getInTransit retourne le groupe")
ctld_test.assertEqual(mgr:getWeight("heli_1"),    436, "getWeight == 436")

-- Another unit has nothing
ctld_test.assert(not mgr:hasTroops("heli_2"),   "heli_2 hasTroops == false (différent)")
ctld_test.assertEqual(mgr:getWeight("heli_2"), 0, "heli_2 getWeight == 0")

-- Remove group
mgr._inTransit["heli_1"] = nil
ctld_test.assert(not mgr:hasTroops("heli_1"),  "hasTroops == false après suppression")
ctld_test.assertEqual(mgr:getWeight("heli_1"), 0, "getWeight == 0 après suppression")

ctld_test.finish()
