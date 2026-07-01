---@diagnostic disable
-- ============================================================
-- U-68 : ctld.utils — vec3Mag, get2DDist, getDistance
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: distances 2D/3D, triangle 3-4-5, guards nil→0
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local function approxEq(a, b, eps)
    return math.abs(a - b) < (eps or 1e-6)
end

ctld_test.start("U-68", "ctld.utils vec3Mag get2DDist getDistance")

-- ── vec3Mag ────────────────────────────────────────────────────
ctld_test.assert(approxEq(ctld.utils.vec3Mag("t", {x=3, y=4, z=0}), 5),    "T1a: mag(3,4,0) == 5")
ctld_test.assert(approxEq(ctld.utils.vec3Mag("t", {x=0, y=0, z=0}), 0),    "T1b: mag(0,0,0) == 0")
ctld_test.assert(approxEq(ctld.utils.vec3Mag("t", {x=1, y=1, z=1}), math.sqrt(3)), "T1c: mag(1,1,1) == √3")
ctld_test.assertEqual(ctld.utils.vec3Mag("t", nil), 0,                       "T1d: nil → 0")
ctld_test.assertEqual(ctld.utils.vec3Mag("t", {x=1, y=nil, z=1}), 0,        "T1e: composante nil → 0")

-- ── get2DDist ─────────────────────────────────────────────────
-- 2D: ignore Y, calcul sur XZ
ctld_test.assert(approxEq(ctld.utils.get2DDist("t", {x=0,y=999,z=0}, {x=3,y=999,z=4}), 5), "T2a: 2D dist 3-4-5")
-- Vec2 input (no z field): makeVec3FromVec2OrVec3 converts y→z
ctld_test.assert(approxEq(ctld.utils.get2DDist("t", {x=0,y=0}, {x=3,y=4}), 5), "T2b: Vec2 input → 2D dist 3-4-5")
ctld_test.assertEqual(ctld.utils.get2DDist("t", nil, {x=0,z=0}), 0,             "T2c: nil point1 → 0")

-- ── getDistance ───────────────────────────────────────────────
ctld_test.assert(approxEq(ctld.utils.getDistance("t", {x=0,z=0}, {x=3,z=4}), 5),  "T3a: getDistance 3-4-5")
ctld_test.assert(approxEq(ctld.utils.getDistance("t", {x=1,z=1}, {x=1,z=1}), 0),  "T3b: même point → 0")
ctld_test.assertEqual(ctld.utils.getDistance("t", nil, {x=0,z=0}), 0,              "T3c: nil point → 0")

ctld_test.finish()
