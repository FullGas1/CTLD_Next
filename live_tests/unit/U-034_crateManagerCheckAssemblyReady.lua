---@diagnostic disable
-- ============================================================
-- U-34 : CTLDCrateManager.checkAssemblyReady
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("U-34", "CTLDCrateManager.checkAssemblyReady")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDCrateManager.getInstance()

-- cratesRequired = 1 → always ready immediately
local desc1 = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local c1 = CTLDCrate:new({ crateName="single_A", descriptor=desc1,
    spawnMethod="crate_spawn", position={x=0,y=0,z=0}, coalition=coalition.side.BLUE })
mgr.crates["single_A"] = c1

local ready, assembled = mgr:checkAssemblyReady(c1, 100)
ctld_test.assert(ready, "cratesRequired=1 → always ready")
ctld_test.assertEqual(#assembled, 1, "assembled list has 1 entry")
ctld_test.assertEqual(assembled[1], c1, "assembled[1] == c1")

-- cratesRequired = 2 : two crates in range → ready
local desc2 = { unit = "KUB_Launcher", cratesRequired = 2 }
local cA = CTLDCrate:new({ crateName="kub_A", descriptor=desc2,
    spawnMethod="crate_spawn", position={x=0,  y=0,z=0}, coalition=coalition.side.BLUE })
local cB = CTLDCrate:new({ crateName="kub_B", descriptor=desc2,
    spawnMethod="crate_spawn", position={x=50, y=0,z=0}, coalition=coalition.side.BLUE })
mgr.crates["kub_A"] = cA
mgr.crates["kub_B"] = cB

local ready2, assembled2 = mgr:checkAssemblyReady(cA, 100)
ctld_test.assert(ready2, "cratesRequired=2 avec 2 crates dans range → ready")
ctld_test.assertEqual(#assembled2, 2, "assembled list has 2 entries")

-- cratesRequired = 2 : second crate out of range → not ready
local cC = CTLDCrate:new({ crateName="kub_C", descriptor=desc2,
    spawnMethod="crate_spawn", position={x=0,  y=0,z=0}, coalition=coalition.side.BLUE })
local cD = CTLDCrate:new({ crateName="kub_D", descriptor=desc2,
    spawnMethod="crate_spawn", position={x=200,y=0,z=0}, coalition=coalition.side.BLUE })
mgr.crates["kub_C"] = cC
mgr.crates["kub_D"] = cD
-- Remove kub_A and kub_B so only C and D exist for this sub-test
mgr.crates["kub_A"] = nil
mgr.crates["kub_B"] = nil

local ready3, assembled3 = mgr:checkAssemblyReady(cC, 100)
ctld_test.assert(not ready3, "cratesRequired=2 avec 1 crate dans range → not ready")
ctld_test.assertEqual(#assembled3, 1, "assembled list has only 1 entry")

-- LOADED crate excluded from assembly
local desc3 = { unit = "NASAMS_Box", cratesRequired = 2 }
local transport = { getName = function() return "heli" end }
local cE = CTLDCrate:new({ crateName="nas_E", descriptor=desc3,
    spawnMethod="crate_spawn", position={x=0, y=0,z=0}, coalition=coalition.side.BLUE })
local cF = CTLDCrate:new({ crateName="nas_F", descriptor=desc3,
    spawnMethod="crate_spawn", position={x=10,y=0,z=0}, coalition=coalition.side.BLUE })
cF:load(transport)   -- LOADED → excluded from assembly
mgr.crates["nas_E"] = cE
mgr.crates["nas_F"] = cF
mgr.crates["kub_C"] = nil
mgr.crates["kub_D"] = nil

local ready4, assembled4 = mgr:checkAssemblyReady(cE, 100)
ctld_test.assert(not ready4, "LOADED crate excluded → only 1 on ground → not ready")
ctld_test.assertEqual(#assembled4, 1, "assembled has 1 (LOADED crate excluded)")

ctld_test.finish()
