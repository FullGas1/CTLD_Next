---@diagnostic disable
-- ============================================================
-- U-32 : CTLDCrateManager singleton + getCrateByName + getCratesInRange
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("U-32", "CTLDCrateManager singleton + getCrateByName + getCratesInRange")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr1 = CTLDCrateManager.getInstance()
ctld_test.assertNotNil(mgr1, "getInstance() retourne une instance")

local mgr2 = CTLDCrateManager.getInstance()
ctld_test.assert(mgr1 == mgr2, "getInstance() idempotent")

-- getCrateByName nil sur registre vide
ctld_test.assertNil(mgr1:getCrateByName("inexistante"), "getCrateByName inconnu == nil")

-- Injecter des crates manuellement dans le registre
local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local c1 = CTLDCrate:new({ crateName="crate_A", descriptor=desc,
    spawnMethod="crate_spawn", position={x=0,y=0,z=0}, coalition=coalition.side.BLUE })
local c2 = CTLDCrate:new({ crateName="crate_B", descriptor=desc,
    spawnMethod="crate_spawn", position={x=50,y=0,z=0}, coalition=coalition.side.BLUE })
local c3 = CTLDCrate:new({ crateName="crate_C", descriptor=desc,
    spawnMethod="crate_spawn", position={x=200,y=0,z=0}, coalition=coalition.side.BLUE })

mgr1.crates["crate_A"] = c1
mgr1.crates["crate_B"] = c2
mgr1.crates["crate_C"] = c3

-- getCrateByName
ctld_test.assertEqual(mgr1:getCrateByName("crate_A"), c1, "getCrateByName('crate_A') == c1")
ctld_test.assertEqual(mgr1:getCrateByName("crate_B"), c2, "getCrateByName('crate_B') == c2")
ctld_test.assertNil(mgr1:getCrateByName("crate_X"),       "getCrateByName inconnu == nil")

-- getCratesInRange depuis (0,0,0), radius=100 → A et B mais pas C
local origin = { x=0, y=0, z=0 }
local inRange = mgr1:getCratesInRange(origin, 100)
ctld_test.assertEqual(#inRange, 2, "getCratesInRange(r=100) retourne 2 crates")

-- getCratesInRange radius=300 → toutes 3
local all3 = mgr1:getCratesInRange(origin, 300)
ctld_test.assertEqual(#all3, 3, "getCratesInRange(r=300) retourne 3 crates")

-- crate LOADED exclue de getCratesInRange
local transport = { getName = function() return "heli" end }
c2:load(transport)
local inRange2 = mgr1:getCratesInRange(origin, 100)
ctld_test.assertEqual(#inRange2, 1, "getCratesInRange exclut les crates LOADED")

ctld_test.finish()
