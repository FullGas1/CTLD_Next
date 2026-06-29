---@diagnostic disable
-- ============================================================
-- U-21 : _worldToLocal + bbox inclusion (algo géométrique pur)
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Tester _worldToLocal et _isInBbox sans DCS.
--
-- Cas :
--   1. Transform identité à l'origine → conversion directe
--   2. Point dans la bbox → _isInBbox == true
--   3. Point hors de la bbox (trop loin en X) → _isInBbox == false
--   4. Transform avec translation (décalage position transport)
--   5. Transform rotatée 90° autour de Y : un point en avant-monde
--      devient un point en X-local
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

CTLDVehicleSpawner._instance = nil
local ok = pcall(function() CTLDVehicleSpawner.getInstance() end)
ctld_test.assert(ok, "CTLDVehicleSpawner init OK")
local vs = CTLDVehicleSpawner._instance

ctld_test.start("U-21", "_worldToLocal + bbox inclusion — algo géométrique pur")

-- ---- Définition de la bbox de référence (approx C-130J-30 cargo bay) ----
-- x = axe forward, z = axe latéral, y = axe vertical
local box = { min = { x=-15, y=-2, z=-3 }, max = { x=15, y=2, z=3 } }

-- ---- Cas 1 : transform identité à l'origine ----
local tfId = {
    p = { x=0, y=0, z=0 },
    x = { x=1, y=0, z=0 },
    y = { x=0, y=1, z=0 },
    z = { x=0, y=0, z=1 },
}

local pt0 = { x=5, y=0, z=0 }
local lp0 = vs:_worldToLocal(pt0, tfId)
ctld_test.assert(math.abs(lp0.x - 5) < 0.001 and math.abs(lp0.z) < 0.001,
    string.format("identité : (5,0,0) → local (%.3f,%.3f,%.3f) ≈ (5,0,0)",
        lp0.x, lp0.y, lp0.z))

-- ---- Cas 2 : point dans la bbox ----
ctld_test.assert(vs:_isInBbox(lp0, box), "lp0 = (5,0,0) dans box [-15..15, -2..2, -3..3]")

-- ---- Cas 3 : point hors bbox (x > max.x) ----
local ptOut = { x=20, y=0, z=0 }
local lpOut = vs:_worldToLocal(ptOut, tfId)
ctld_test.assert(not vs:_isInBbox(lpOut, box),
    string.format("lpOut = (%.1f,%.1f,%.1f) hors bbox (x>15)", lpOut.x, lpOut.y, lpOut.z))

-- ---- Cas 4 : transform avec translation ----
local tfT = {
    p = { x=1000, y=0, z=2000 },
    x = { x=1, y=0, z=0 },
    y = { x=0, y=1, z=0 },
    z = { x=0, y=0, z=1 },
}
local ptT = { x=1005, y=0, z=2000 }   -- 5 m en x local
local lpT = vs:_worldToLocal(ptT, tfT)
ctld_test.assert(math.abs(lpT.x - 5) < 0.001,
    string.format("translation : (1005,0,2000) → local.x ≈ 5 (got %.3f)", lpT.x))
ctld_test.assert(vs:_isInBbox(lpT, box), "lpT dans bbox après translation")

-- ---- Cas 5 : rotation 90° CW autour de Y (forward = world +Z) ----
-- x-local = world Z, z-local = -world X
local tfR90 = {
    p = { x=0, y=0, z=0 },
    x = { x=0, y=0, z=1 },   -- forward = world +Z
    y = { x=0, y=1, z=0 },   -- up = world +Y
    z = { x=-1, y=0, z=0 },  -- right = world -X
}
-- Un point 5 m "en avant" du transport = world +Z direction
local ptR = { x=0, y=0, z=5 }
local lpR = vs:_worldToLocal(ptR, tfR90)
ctld_test.assert(math.abs(lpR.x - 5) < 0.001,
    string.format("rotation 90° : monde +Z 5m → local.x ≈ 5 (got %.3f)", lpR.x))
ctld_test.assert(vs:_isInBbox(lpR, box), "lpR dans bbox après rotation")

-- ---- Cas 6 : point hors bbox sur Z latéral ----
local ptLat = { x=0, y=0, z=5 }   -- local z = 5 > box.max.z=3 si x est ok mais z>3
-- Utilisons transform identité et z=5
local lpLat = vs:_worldToLocal({ x=0, y=0, z=5 }, tfId)
ctld_test.assert(not vs:_isInBbox(lpLat, box),
    string.format("lpLat = (0,0,5) hors bbox (z>3)", lpLat.x))

ctld_test.finish()
