---@diagnostic disable
-- ============================================================
-- U-11 : CTLDTroopZone.isInZone — circulaire
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Vérifier qu'un point à l'intérieur du rayon retourne true
--           et qu'un point au-delà retourne false.
--           Pas d'appel DCS nécessaire : ctld.utils.getDistance est pur.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("U-11", "CTLDTroopZone.isInZone — circulaire")

local center = { x = 1000, y = 0, z = 2000 }
local radius = 500

local zone = CTLDTroopZone:new({
    dcsName  = "TRZ_test_B",
    zoneName = "test",
    coalition = 2,
    center   = center,
    radius   = radius,
})

-- Point exactement au centre → dedans
local ptCenter = { x = 1000, y = 0, z = 2000 }
ctld_test.assert(zone:isInZone(ptCenter), "centre de zone : isInZone == true")

-- Point à 400 m du centre (< 500 m) → dedans
local ptInside = { x = 1000 + 400, y = 0, z = 2000 }
ctld_test.assert(zone:isInZone(ptInside), "point à 400m : isInZone == true")

-- Point exactement sur le bord (≈ 500 m) → dedans (<=)
local ptEdge = { x = 1000 + 500, y = 0, z = 2000 }
ctld_test.assert(zone:isInZone(ptEdge), "point à 500m (bord) : isInZone == true")

-- Point à 501 m → dehors
local ptOutside = { x = 1000 + 501, y = 0, z = 2000 }
ctld_test.assert(not zone:isInZone(ptOutside), "point à 501m : isInZone == false")

-- Point à 1000 m → dehors
local ptFar = { x = 1000 + 1000, y = 0, z = 2000 }
ctld_test.assert(not zone:isInZone(ptFar), "point à 1000m : isInZone == false")

-- Point en diagonale (distance Pythagorienne) — dedans
-- sqrt(300^2 + 300^2) ≈ 424 m < 500 m
local ptDiagIn = { x = 1000 + 300, y = 0, z = 2000 + 300 }
ctld_test.assert(zone:isInZone(ptDiagIn), "point diagonal 424m : isInZone == true")

-- Point en diagonale — dehors
-- sqrt(400^2 + 400^2) ≈ 566 m > 500 m
local ptDiagOut = { x = 1000 + 400, y = 0, z = 2000 + 400 }
ctld_test.assert(not zone:isInZone(ptDiagOut), "point diagonal 566m : isInZone == false")

ctld_test.finish()
