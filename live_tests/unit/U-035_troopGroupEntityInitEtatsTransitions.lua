---@diagnostic disable
-- ============================================================
-- U-35 : CTLDTroopGroup entity — init + états + transitions
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("U-35", "CTLDTroopGroup entity — init + états + transitions")

local data = {
    templateKey  = "troop_1_squad",
    templateName = "Infantry Squad",
    unitTotal    = 5,
    weight       = 545,
    hasJtac      = false,
    coalitionId  = coalition.side.BLUE,
    countryId    = 2,
}

local g = CTLDTroopGroup:new(data)
ctld_test.assertNotNil(g, "CTLDTroopGroup:new() retourne un objet")
ctld_test.assertEqual(g.templateKey,  "troop_1_squad",         "templateKey correct")
ctld_test.assertEqual(g.templateName, "Infantry Squad",        "templateName correct")
ctld_test.assertEqual(g.unitTotal,    5,                       "unitTotal == 5")
ctld_test.assertEqual(g.weight,       545,                     "weight == 545")
ctld_test.assertEqual(g.hasJtac,      false,                   "hasJtac == false")
ctld_test.assertEqual(g.coalitionId,  coalition.side.BLUE,     "coalitionId == BLUE")
ctld_test.assertEqual(g.state,        CTLDTroopGroup.STATE.LOADED, "état initial == LOADED")
ctld_test.assertNil(g.dcsGroup,       "dcsGroup == nil à l'init")

-- isInTransit: LOADED → true
ctld_test.assert(g:isInTransit(), "isInTransit() == true à l'état LOADED")

-- deploy
local mockGroup = { getName = function() return "MockGroup" end }
g:deploy(mockGroup)
ctld_test.assertEqual(g.state,    CTLDTroopGroup.STATE.DEPLOYED, "état == DEPLOYED après deploy()")
ctld_test.assertEqual(g.dcsGroup, mockGroup,                     "dcsGroup set après deploy()")
ctld_test.assert(not g:isInTransit(), "isInTransit() == false à l'état DEPLOYED")

-- deploy nil (EXZ silent drop)
local g2 = CTLDTroopGroup:new(data)
g2:deploy(nil)
ctld_test.assertEqual(g2.state,   CTLDTroopGroup.STATE.DEPLOYED, "deploy(nil) → DEPLOYED")
ctld_test.assertNil(g2.dcsGroup,  "dcsGroup == nil pour EXZ drop")

-- extract
local g3 = CTLDTroopGroup:new(data)
g3:deploy(mockGroup)
g3:extract()
ctld_test.assertEqual(g3.state,   CTLDTroopGroup.STATE.EXTRACTED, "état == EXTRACTED après extract()")
ctld_test.assertNil(g3.dcsGroup,  "dcsGroup == nil après extract()")
ctld_test.assert(g3:isInTransit(), "isInTransit() == true à l'état EXTRACTED")

-- hasJtac=true
local g4 = CTLDTroopGroup:new({ templateKey="k", templateName="JTAC Sq",
    unitTotal=2, weight=248, hasJtac=true, coalitionId=coalition.side.BLUE, countryId=2 })
ctld_test.assert(g4.hasJtac, "hasJtac == true si données init")

ctld_test.finish()
