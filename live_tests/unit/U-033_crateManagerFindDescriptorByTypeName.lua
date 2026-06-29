---@diagnostic disable
-- ============================================================
-- U-33 : CTLDCrateManager.findDescriptorByTypeName
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("U-33", "CTLDCrateManager.findDescriptorByTypeName")

-- Inject a fake spawnableCrates config
local fakeSpawnableCrates = {
    ammo = {
        { unit = "M92_Ammo_Pallet",  cratesRequired = 1 },
        { unit = "JTAC_MarkerPanel", cratesRequired = 2 },
    },
    vehicles = {
        { unit = "M1045 HMMWV TOW", type = "alt_type_name", cratesRequired = 3 },
    },
}
CTLDConfig.get().settings["spawnableCrates"] = fakeSpawnableCrates

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDCrateManager.getInstance()

-- Match by .unit field
local d1 = mgr:findDescriptorByTypeName("M92_Ammo_Pallet")
ctld_test.assertNotNil(d1, "findDescriptorByTypeName('M92_Ammo_Pallet') ~= nil")
ctld_test.assertEqual(d1.unit, "M92_Ammo_Pallet", "descriptor.unit == 'M92_Ammo_Pallet'")
ctld_test.assertEqual(d1.cratesRequired, 1, "descriptor.cratesRequired == 1")

local d2 = mgr:findDescriptorByTypeName("JTAC_MarkerPanel")
ctld_test.assertNotNil(d2, "findDescriptorByTypeName('JTAC_MarkerPanel') ~= nil")
ctld_test.assertEqual(d2.cratesRequired, 2, "JTAC_MarkerPanel cratesRequired == 2")

-- Match by .type field (alternate type name)
local d3 = mgr:findDescriptorByTypeName("alt_type_name")
ctld_test.assertNotNil(d3, "findDescriptorByTypeName via .type field ~= nil")
ctld_test.assertEqual(d3.unit, "M1045 HMMWV TOW", "descriptor.unit correct via .type match")

-- Unknown typeName returns nil
local d4 = mgr:findDescriptorByTypeName("UnknownType_XYZ")
ctld_test.assertNil(d4, "findDescriptorByTypeName inconnu == nil")

-- nil input returns nil
local d5 = mgr:findDescriptorByTypeName(nil)
ctld_test.assertNil(d5, "findDescriptorByTypeName(nil) == nil")

ctld_test.finish()
