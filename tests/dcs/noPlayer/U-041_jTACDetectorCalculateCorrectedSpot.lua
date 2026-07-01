---@diagnostic disable
-- ============================================================
-- U-41 : CTLDJTACDetector.calculateCorrectedSpot
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

ctld_test.start("U-41", "CTLDJTACDetector.calculateCorrectedSpot")

-- Formula: corrected.x = targetPos.x + vel.x*1.0 - wind.x*1.05  (y unchanged, z idem)

-- Static target (vel=0, wind=0) → same position
local pos = { x=100, y=10, z=200 }
local vel = { x=0,   y=0,  z=0   }
local wind = { x=0,  y=0,  z=0   }
local r1 = CTLDJTACDetector.calculateCorrectedSpot(pos, vel, wind)
ctld_test.assertEqual(r1.x, 100, "x inchangé (vel=0, wind=0)")
ctld_test.assertEqual(r1.y, 10,  "y toujours == targetPos.y")
ctld_test.assertEqual(r1.z, 200, "z inchangé (vel=0, wind=0)")

-- Moving target (+10 m/s), no wind → anticipation 1s
local vel2 = { x=10, y=0, z=5 }
local r2 = CTLDJTACDetector.calculateCorrectedSpot(pos, vel2, wind)
ctld_test.assertEqual(r2.x, 110, "x = 100 + 10*1.0 = 110")
ctld_test.assertEqual(r2.z, 205, "z = 200 + 5*1.0 = 205")

-- Wind correction (wind.x=4, wind.z=2, anticipation*1.05 applied)
local wind3 = { x=4, y=0, z=2 }
local r3 = CTLDJTACDetector.calculateCorrectedSpot(pos, vel, wind3)
-- x = 100 + 0 - 4*1.05 = 100 - 4.2 = 95.8
-- z = 200 + 0 - 2*1.05 = 200 - 2.1 = 197.9
ctld_test.assertEqual(r3.x, 95.8,  "x = 100 - 4*1.05 = 95.8")
ctld_test.assertEqual(r3.z, 197.9, "z = 200 - 2*1.05 = 197.9")
ctld_test.assertEqual(r3.y, 10,    "y inchangé même avec vent")

-- Moving target + wind combined
local vel4  = { x=10, y=0, z=0 }
local wind4 = { x=4,  y=0, z=0 }
local r4 = CTLDJTACDetector.calculateCorrectedSpot(pos, vel4, wind4)
-- x = 100 + 10*1.0 - 4*1.05 = 110 - 4.2 = 105.8
ctld_test.assertEqual(r4.x, 105.8, "x = 100 + 10 - 4*1.05 = 105.8")

ctld_test.finish()
