---@diagnostic disable
-- ============================================================
-- F-78 : ctld.utils.getCentroid
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: 4 points → centroïde x/z correct (mock land.getHeight)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local function approxEq(a, b, eps)
    return math.abs(a - b) < (eps or 1e-6)
end

-- ── Mock land.getHeight ───────────────────────────────────────
local _origGetHeight = land.getHeight
land.getHeight = function(pos) return 42 end   -- terrain plat à 42m

ctld_test.start("F-78", "ctld.utils getCentroid")

-- T1: 4 points → centroïde = moyenne x et z
--   points: (0,0), (10,0), (10,10), (0,10) → centre (5,5)
local pts = {
    { x =  0, z =  0 },
    { x = 10, z =  0 },
    { x = 10, z = 10 },
    { x =  0, z = 10 },
}
local c = ctld.utils.getCentroid("t", pts)
ctld_test.assertNotNil(c,                     "T1a: getCentroid retourne un résultat")
ctld_test.assert(approxEq(c.x, 5),            "T1b: centroïde x == 5")
ctld_test.assert(approxEq(c.z, 5),            "T1c: centroïde z == 5")
ctld_test.assertEqual(c.y, 42,                "T1d: y == land.getHeight() == 42")

-- T2: 3 points alignés → centroïde sur la ligne
local pts2 = { {x=0,z=0}, {x=6,z=0}, {x=3,z=9} }
local c2 = ctld.utils.getCentroid("t", pts2)
ctld_test.assert(approxEq(c2.x, 3),           "T2a: centroïde x == 3")
ctld_test.assert(approxEq(c2.z, 3),           "T2b: centroïde z == 3")

-- T3: table vide → nil
ctld_test.assertNil(ctld.utils.getCentroid("t", {}),  "T3a: table vide → nil")
ctld_test.assertNil(ctld.utils.getCentroid("t", nil), "T3b: nil → nil")

-- Restore
land.getHeight = _origGetHeight

ctld_test.finish()
