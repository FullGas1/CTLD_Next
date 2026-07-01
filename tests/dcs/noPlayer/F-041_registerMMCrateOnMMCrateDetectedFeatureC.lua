---@diagnostic disable
-- ============================================================
-- F-41 : registerMMCrate → OnMMCrateDetected (Feature C)
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("F-41", "registerMMCrate → OnMMCrateDetected")

CTLDConfig.get().settings["spawnableCrates"] = {
    ammo = { { unit = "M92_Ammo_Pallet", cratesRequired = 1 } },
}

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local dispatcher = EventDispatcher.getInstance()
local mgr = CTLDCrateManager.getInstance()

local mockPos = { x = 100, y = 5, z = 200 }
local mockStatic = {
    getName      = function(self) return "mm_cargo_01" end,
    getPoint     = function(self) return mockPos end,
    getCoalition = function(self) return coalition.side.BLUE end,
    isExist      = function(self) return true end,
}
local mockDesc = { typeName = "M92_Ammo_Pallet" }

-- Subscribe to OnMMCrateDetected
local received = nil
dispatcher:subscribe("OnMMCrateDetected", function(payload)
    received = payload
end)

mgr:registerMMCrate(mockStatic, mockDesc)

-- Event received
ctld_test.assertNotNil(received,                             "OnMMCrateDetected reçu")
ctld_test.assertEqual(received.crateName, "mm_cargo_01",    "payload.crateName correct")
ctld_test.assertEqual(received.coalition, coalition.side.BLUE, "payload.coalition correct")
ctld_test.assertEqual(received.descriptor.unit, "M92_Ammo_Pallet", "payload.descriptor.unit correct")
ctld_test.assertNotNil(received.position,                   "payload.position présent")
ctld_test.assertNotNil(received.crate,                      "payload.crate présent")
ctld_test.assertNotNil(received.timestamp,                  "payload.timestamp présent")

-- Double registration does NOT fire event again
local received2 = nil
dispatcher:subscribe("OnMMCrateDetected", function(p) received2 = p end)
mgr:registerMMCrate(mockStatic, mockDesc)
ctld_test.assertNil(received2, "double registration → pas de 2ème OnMMCrateDetected")

-- Unknown type does NOT fire event
local received3 = nil
dispatcher:subscribe("OnMMCrateDetected", function(p) received3 = p end)
local mockStatic2 = {
    getName      = function(self) return "mm_cargo_02" end,
    getPoint     = function(self) return mockPos end,
    getCoalition = function(self) return coalition.side.BLUE end,
    isExist      = function(self) return true end,
}
mgr:registerMMCrate(mockStatic2, { typeName = "UNKNOWN_XYZ" })
ctld_test.assertNil(received3, "type inconnu → pas d'OnMMCrateDetected")

ctld_test.finish()
