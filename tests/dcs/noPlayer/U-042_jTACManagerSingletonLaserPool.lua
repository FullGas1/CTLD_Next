---@diagnostic disable
-- ============================================================
-- U-42 : CTLDJTACManager singleton + laser pool
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

ctld_test.start("U-42", "CTLDJTACManager singleton + laser pool")

CTLDJTACManager._instance = nil

local mgr1 = CTLDJTACManager.get()
ctld_test.assertNotNil(mgr1, "get() retourne une instance")

local mgr2 = CTLDJTACManager.get()
ctld_test.assert(mgr1 == mgr2, "get() idempotent (singleton)")

-- Laser pool: 1111–1688 = 578 codes
local expectedCount = 1688 - 1111 + 1   -- 578
ctld_test.assertEqual(#mgr1._laserPool, expectedCount,
    "_laserPool initialisé avec " .. expectedCount .. " codes")

-- First assigned code == 1688 (tail removal)
local code1 = mgr1:_assignLaserCode()
ctld_test.assertEqual(code1, 1688, "premier code assigné == 1688 (tail)")
ctld_test.assertEqual(#mgr1._laserPool, expectedCount - 1, "pool réduit de 1")

-- Second code
local code2 = mgr1:_assignLaserCode()
ctld_test.assertEqual(code2, 1687, "deuxième code == 1687")

-- Free a code → goes back to pool tail
mgr1:_freeLaserCode(code1)
ctld_test.assertEqual(#mgr1._laserPool, expectedCount - 1, "free → pool +1 (toujours -1 du total car code2 sorti)")
ctld_test.assertEqual(mgr1._laserPool[#mgr1._laserPool], code1, "code libéré en queue du pool")

-- _freeLaserCode(nil) is safe
local okFree = pcall(function() mgr1:_freeLaserCode(nil) end)
ctld_test.assert(okFree, "_freeLaserCode(nil) ne crash pas")

-- Pool exhaustion: drain remaining codes
-- Re-init fresh to avoid draining the real pool
mgr1:_initLaserPool()
ctld_test.assertEqual(#mgr1._laserPool, expectedCount, "_initLaserPool restaure le pool complet")

-- Structs
ctld_test.assertNotNil(mgr1.jtacs,         "mgr.jtacs table présente")
ctld_test.assertNotNil(mgr1._pendingJTACs, "mgr._pendingJTACs table présente")

ctld_test.finish()
