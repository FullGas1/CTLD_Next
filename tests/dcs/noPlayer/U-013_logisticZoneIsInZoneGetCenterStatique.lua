---@diagnostic disable
-- ============================================================
-- U-13 : CTLDLogisticZone isInZone + getCenter (statique)
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Zone statique (pas de linkedUnit) :
--   - isInZone : dedans / dehors
--   - getCenter : retourne le center fixe
--   - isAlive  : toujours true sans linkedUnit
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("U-13", "CTLDLogisticZone isInZone + getCenter (statique)")

local center = { x = 5000, y = 0, z = 3000 }
local radius = 200

local lgz = CTLDLogisticZone:new({
    name      = "testLGZ",
    coalition = 2,
    center    = center,
    radius    = radius,
    active    = true,
})

-- getCenter : retourne exactement le center fourni (zone statique)
local c = lgz:getCenter()
ctld_test.assertNotNil(c, "getCenter() non-nil")
ctld_test.assertEqual(c.x, center.x, "getCenter().x == 5000")
ctld_test.assertEqual(c.z, center.z, "getCenter().z == 3000")

-- isAlive : toujours true sans linkedUnit
ctld_test.assert(lgz:isAlive(), "isAlive() == true (pas de linkedUnit)")

-- isDynamic : false pour zone statique
ctld_test.assert(not lgz:isDynamic(), "isDynamic() == false")

-- isInZone : dedans
local ptIn = { x = 5100, y = 0, z = 3000 }  -- 100 m du centre
ctld_test.assert(lgz:isInZone(ptIn), "point à 100m : isInZone == true")

-- isInZone : exactement sur le bord
local ptEdge = { x = 5000 + 200, y = 0, z = 3000 }
ctld_test.assert(lgz:isInZone(ptEdge), "point à 200m (bord) : isInZone == true")

-- isInZone : dehors
local ptOut = { x = 5000 + 201, y = 0, z = 3000 }
ctld_test.assert(not lgz:isInZone(ptOut), "point à 201m : isInZone == false")

-- isInZone : loin
local ptFar = { x = 5000 + 1000, y = 0, z = 3000 }
ctld_test.assert(not lgz:isInZone(ptFar), "point à 1000m : isInZone == false")

-- services par défaut présents
ctld_test.assertNotNil(lgz.services, "services non-nil")
ctld_test.assert(lgz.services.cratesPickup  == true, "service cratesPickup == true")
ctld_test.assert(lgz.services.vehicleSpawn  == true, "service vehicleSpawn == true")

ctld_test.finish()
