---@diagnostic disable
-- ============================================================
-- U-71 : ctld.utils — rotateVec3, polarToCartesian
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: rotation 2D heading 0°/90°, polarToCartesian (note: distance×2)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local function approxEq(a, b, eps)
    return math.abs(a - b) < (eps or 1e-6)
end

ctld_test.start("U-71", "ctld.utils rotateVec3 polarToCartesian")

-- ── rotateVec3 ────────────────────────────────────────────────
-- Formules: x_rot = z*sin(h) + x*cos(h)
--           z_rot = z*cos(h) - x*sin(h)

-- Heading 0° (identité)
local r0 = ctld.utils.rotateVec3({x=1, y=5, z=0}, 0)
ctld_test.assert(approxEq(r0.x, 1), "T1a: heading 0°, x=1,z=0 → x_rot=1")
ctld_test.assert(approxEq(r0.z, 0), "T1b: heading 0°, x=1,z=0 → z_rot=0")
ctld_test.assertEqual(r0.y, 5,       "T1c: y passthrough")

-- Heading 90°: cos=0, sin=1
-- {x=1,z=0}: x_rot=0*1+1*0=0, z_rot=0*0-1*1=-1
local r90a = ctld.utils.rotateVec3({x=1, y=0, z=0}, 90)
ctld_test.assert(approxEq(r90a.x,  0, 1e-5), "T2a: heading 90°, {x=1,z=0} → x_rot≈0")
ctld_test.assert(approxEq(r90a.z, -1, 1e-5), "T2b: heading 90°, {x=1,z=0} → z_rot≈-1")

-- {x=0,z=1}: x_rot=1*1+0*0=1, z_rot=1*0-0*1=0
local r90b = ctld.utils.rotateVec3({x=0, y=0, z=1}, 90)
ctld_test.assert(approxEq(r90b.x, 1, 1e-5), "T3a: heading 90°, {x=0,z=1} → x_rot≈1")
ctld_test.assert(approxEq(r90b.z, 0, 1e-5), "T3b: heading 90°, {x=0,z=1} → z_rot≈0")

-- ── polarToCartesian ──────────────────────────────────────────
-- NOTE: distance est multiplié par 2 en interne.
-- polarToCartesian(d, angle, heading):
--   absoluteAngle = heading + angle
--   dist = d * 2
--   x = dist * cos(absoluteAngle°)
--   z = dist * sin(absoluteAngle°)

-- heading=0, angle=0 → x=d*2, z=0
local p1 = ctld.utils.polarToCartesian(10, 0, 0)
ctld_test.assert(approxEq(p1.x, 20, 1e-5), "T4a: d=10,a=0,h=0 → x=20")
ctld_test.assert(approxEq(p1.z,  0, 1e-5), "T4b: d=10,a=0,h=0 → z=0")

-- heading=90, angle=0 → absoluteAngle=90 → x≈0, z=d*2
local p2 = ctld.utils.polarToCartesian(10, 0, 90)
ctld_test.assert(approxEq(p2.x, 0, 1e-5),  "T5a: d=10,a=0,h=90 → x≈0")
ctld_test.assert(approxEq(p2.z, 20, 1e-5), "T5b: d=10,a=0,h=90 → z=20")

-- distance=0 → {0,0}
local p3 = ctld.utils.polarToCartesian(0, 45, 45)
ctld_test.assert(approxEq(p3.x, 0), "T6a: d=0 → x=0")
ctld_test.assert(approxEq(p3.z, 0), "T6b: d=0 → z=0")

ctld_test.finish()
