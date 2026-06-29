---@diagnostic disable
-- ============================================================
-- U-70 : ctld.utils — makeVec3FromVec2OrVec3, makeVec2FromVec3OrVec2
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: conversions Vec2↔Vec3, passthrough, nil guard
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-70", "ctld.utils makeVec3FromVec2OrVec3 makeVec2FromVec3OrVec2")

-- ── makeVec3FromVec2OrVec3 ────────────────────────────────────

-- Vec2 {x,y} (no z) → Vec3: y devient z, y=0
local v2 = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=4})
ctld_test.assertEqual(v2.x, 1, "T1a: Vec2→Vec3 x == 1")
ctld_test.assertEqual(v2.z, 4, "T1b: Vec2→Vec3 z == y_original == 4")
ctld_test.assertEqual(v2.y, 0, "T1c: Vec2→Vec3 y == 0 (pas d'alt)")

-- Vec2 avec alt → y = alt
local v2alt = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=4, alt=100})
ctld_test.assertEqual(v2alt.y, 100, "T1d: Vec2 avec alt → y == 100")

-- Vec2 + y explicite → y = y param
local v2y = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=4}, 50)
ctld_test.assertEqual(v2y.y, 50, "T1e: Vec2 + y param → y == 50")

-- Vec3 passthrough (a z field) → retourné tel quel
local v3 = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=2, z=3})
ctld_test.assertEqual(v3.x, 1, "T2a: Vec3 passthrough x == 1")
ctld_test.assertEqual(v3.y, 2, "T2b: Vec3 passthrough y == 2")
ctld_test.assertEqual(v3.z, 3, "T2c: Vec3 passthrough z == 3")

-- nil → nil
ctld_test.assertNil(ctld.utils.makeVec3FromVec2OrVec3("t", nil), "T3: nil → nil")

-- ── makeVec2FromVec3OrVec2 ────────────────────────────────────

-- Vec3 {x,y,z} → Vec2: {x, y=z}
local r3 = ctld.utils.makeVec2FromVec3OrVec2("t", {x=5, y=10, z=20})
ctld_test.assertEqual(r3.x, 5,  "T4a: Vec3→Vec2 x == 5")
ctld_test.assertEqual(r3.y, 20, "T4b: Vec3→Vec2 y == z_original == 20")

-- Vec2 passthrough (no z)
local r2 = ctld.utils.makeVec2FromVec3OrVec2("t", {x=7, y=8})
ctld_test.assertEqual(r2.x, 7, "T5a: Vec2 passthrough x == 7")
ctld_test.assertEqual(r2.y, 8, "T5b: Vec2 passthrough y == 8")

-- nil → nil
ctld_test.assertNil(ctld.utils.makeVec2FromVec3OrVec2("t", nil), "T6: nil → nil")

ctld_test.finish()
