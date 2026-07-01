---@diagnostic disable
-- ============================================================
-- U-69 : ctld.utils — addVec3, subVec3, multVec3
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: opérations vectorielles, nil guards
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-69", "ctld.utils addVec3 subVec3 multVec3")

-- ── addVec3 ───────────────────────────────────────────────────
local sum = ctld.utils.addVec3({x=1,y=2,z=3}, {x=4,y=5,z=6})
ctld_test.assertEqual(sum.x, 5, "T1a: addVec3 x = 5")
ctld_test.assertEqual(sum.y, 7, "T1b: addVec3 y = 7")
ctld_test.assertEqual(sum.z, 9, "T1c: addVec3 z = 9")

-- addVec3 tolère les champs nil (or 0)
local sumNil = ctld.utils.addVec3({x=1}, {z=3})
ctld_test.assertEqual(sumNil.x, 1, "T1d: addVec3 nil fields → x = 1")
ctld_test.assertEqual(sumNil.z, 3, "T1e: addVec3 nil fields → z = 3")

-- ── subVec3 ───────────────────────────────────────────────────
local diff = ctld.utils.subVec3("t", {x=5,y=5,z=5}, {x=1,y=2,z=3})
ctld_test.assertEqual(diff.x, 4, "T2a: subVec3 x = 4")
ctld_test.assertEqual(diff.y, 3, "T2b: subVec3 y = 3")
ctld_test.assertEqual(diff.z, 2, "T2c: subVec3 z = 2")

-- nil guard → nil retourné
ctld_test.assertNil(ctld.utils.subVec3("t", nil, {x=0,y=0,z=0}), "T2d: subVec3(nil,...) → nil")

-- ── multVec3 (dot product) ────────────────────────────────────
-- (1,0,0)·(1,0,0) = 1
ctld_test.assertEqual(ctld.utils.multVec3("t", {x=1,y=0,z=0}, {x=1,y=0,z=0}), 1, "T3a: dot (1,0,0)·(1,0,0) = 1")
-- (1,0,0)·(0,1,0) = 0 (orthogonal)
ctld_test.assertEqual(ctld.utils.multVec3("t", {x=1,y=0,z=0}, {x=0,y=1,z=0}), 0, "T3b: dot orthogonal = 0")
-- (2,3,4)·(5,6,7) = 10+18+28 = 56
ctld_test.assertEqual(ctld.utils.multVec3("t", {x=2,y=3,z=4}, {x=5,y=6,z=7}), 56, "T3c: dot (2,3,4)·(5,6,7) = 56")
-- nil guard → 0
ctld_test.assertEqual(ctld.utils.multVec3("t", nil, {x=1,y=0,z=0}), 0, "T3d: multVec3(nil,...) → 0")

ctld_test.finish()
