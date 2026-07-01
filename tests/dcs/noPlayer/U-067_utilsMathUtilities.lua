---@diagnostic disable
-- ============================================================
-- U-67 : ctld.utils — math utilities
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: round, radianToDegree, normalizeHeadingInDegrees, kmphToMps
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local function approxEq(a, b, eps)
    return math.abs(a - b) < (eps or 1e-9)
end

ctld_test.start("U-67", "ctld.utils math utilities")

-- ── round ──────────────────────────────────────────────────────
ctld_test.assert(approxEq(ctld.utils.round("t", 3.456, 2), 3.46),  "T1a: round(3.456,2) == 3.46")
ctld_test.assert(approxEq(ctld.utils.round("t", 3.5,   0), 4),     "T1b: round(3.5,0) == 4")
ctld_test.assert(approxEq(ctld.utils.round("t", -2.5,  0), -2),    "T1c: round(-2.5,0) == -2 (floor)")
ctld_test.assertEqual(ctld.utils.round("t", nil), 0,                "T1d: round(nil) → 0")

-- ── radianToDegree ─────────────────────────────────────────────
ctld_test.assert(approxEq(ctld.utils.radianToDegree("t", math.pi), 180),     "T2a: rad(π) == 180°")
ctld_test.assert(approxEq(ctld.utils.radianToDegree("t", math.pi/2), 90),    "T2b: rad(π/2) == 90°")
ctld_test.assertEqual(ctld.utils.radianToDegree("t", nil), 0,                 "T2c: radianToDegree(nil) → 0")

-- ── normalizeHeadingInDegrees ──────────────────────────────────
ctld_test.assert(approxEq(ctld.utils.normalizeHeadingInDegrees("t", 370), 10),  "T3a: 370° → 10°")
ctld_test.assert(approxEq(ctld.utils.normalizeHeadingInDegrees("t", -90), 270), "T3b: -90° → 270°")
ctld_test.assert(approxEq(ctld.utils.normalizeHeadingInDegrees("t", 360), 0),   "T3c: 360° → 0°")
ctld_test.assertEqual(ctld.utils.normalizeHeadingInDegrees("t", nil), 0,         "T3d: nil → 0")

-- ── kmphToMps ──────────────────────────────────────────────────
ctld_test.assert(approxEq(ctld.utils.kmphToMps("t", 360), 100),  "T4a: 360 km/h → 100 m/s")
ctld_test.assert(approxEq(ctld.utils.kmphToMps("t", 0),   0),    "T4b: 0 km/h → 0 m/s")
ctld_test.assertEqual(ctld.utils.kmphToMps("t", nil), 0,          "T4c: nil → 0")

ctld_test.finish()
