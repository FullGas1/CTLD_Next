---@diagnostic disable
-- ============================================================
-- U-73 : ctld.utils — zoneToVec3 (branche table uniquement)
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: table {point=}, table {x,y,z}, nil guard — sans DCS trigger.misc
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-73", "ctld.utils zoneToVec3 branche table")

-- T1: zone comme table {point={x,y,z}} → extrait point
local z1 = ctld.utils.zoneToVec3("t", { point = { x = 100, y = 50, z = 200 } })
ctld_test.assertNotNil(z1,           "T1a: zone {point} → résultat non-nil")
ctld_test.assertEqual(z1.x, 100,     "T1b: x == 100")
ctld_test.assertEqual(z1.y, 50,      "T1c: y == 50")
ctld_test.assertEqual(z1.z, 200,     "T1d: z == 200")

-- T2: zone comme table {x,y,z} (deepCopy branch)
local z2 = ctld.utils.zoneToVec3("t", { x = 10, y = 20, z = 30 })
ctld_test.assertNotNil(z2,           "T2a: zone {x,y,z} → résultat non-nil")
ctld_test.assertEqual(z2.x, 10,      "T2b: x == 10")
ctld_test.assertEqual(z2.z, 30,      "T2c: z == 30")

-- T3: nil → nil retourné
ctld_test.assertNil(ctld.utils.zoneToVec3("t", nil), "T3: nil zone → nil")

ctld_test.finish()
