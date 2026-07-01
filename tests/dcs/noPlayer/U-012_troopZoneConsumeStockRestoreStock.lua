---@diagnostic disable
-- ============================================================
-- U-12 : CTLDTroopZone consumeStock / restoreStock
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Tester la gestion du stock :
--   - Stock limité  : consomme, refuse si insuffisant, restaure
--   - Stock illimité (pickMaxStock == 0) : consomme toujours true
--   - Zone sans pickup (pickMaxStock == nil) : consume retourne false
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("U-12", "CTLDTroopZone consumeStock / restoreStock")

local center = { x = 0, y = 0, z = 0 }

-- ---- Zone à stock limité (pickMaxStock = 10) ----
local zLimited = CTLDTroopZone:new({
    dcsName  = "TRZ_limited_B", zoneName = "limited",
    coalition = 2, center = center, radius = 300,
    pickMaxStock = 10,
})

ctld_test.assertEqual(zLimited.pickCurrentStock, 10, "stock initial == 10")

-- Consommation normale
ctld_test.assert(zLimited:consumeStock(3), "consumeStock(3) retourne true")
ctld_test.assertEqual(zLimited.pickCurrentStock, 7, "stock après consume(3) == 7")

-- Consommation exacte du reste
ctld_test.assert(zLimited:consumeStock(7), "consumeStock(7) retourne true (stock exact)")
ctld_test.assertEqual(zLimited.pickCurrentStock, 0, "stock == 0 après consume du reste")

-- Consommation sur stock vide → false
ctld_test.assert(not zLimited:consumeStock(1), "consumeStock(1) sur stock 0 retourne false")
ctld_test.assertEqual(zLimited.pickCurrentStock, 0, "stock reste 0 après refus")

-- Restauration
zLimited:restoreStock(5)
ctld_test.assertEqual(zLimited.pickCurrentStock, 5, "restoreStock(5) → stock == 5")

-- Restauration plafonnée au max
zLimited:restoreStock(20)
ctld_test.assertEqual(zLimited.pickCurrentStock, 10, "restoreStock(20) plafonné à pickMaxStock=10")

-- ---- Zone à stock illimité (pickMaxStock = 0) ----
local zUnlimited = CTLDTroopZone:new({
    dcsName = "TRZ_unlimited_B", zoneName = "unlimited",
    coalition = 2, center = center, radius = 300,
    pickMaxStock = 0,
})

ctld_test.assert(zUnlimited:consumeStock(100), "zone illimitée : consumeStock(100) == true")
ctld_test.assert(zUnlimited:consumeStock(1),   "zone illimitée : consumeStock(1) == true (après)")
ctld_test.assertEqual(zUnlimited.pickCurrentStock, 0, "zone illimitée : pickCurrentStock reste 0")

-- restoreStock sur zone illimitée → no-op (pas d'erreur)
local ok = pcall(function() zUnlimited:restoreStock(5) end)
ctld_test.assert(ok, "zone illimitée : restoreStock ne crash pas (no-op)")

-- ---- Zone sans pickup (pickMaxStock = nil) ----
local zNoPickup = CTLDTroopZone:new({
    dcsName = "TRZ_nopickup", zoneName = "nopickup",
    coalition = 0, center = center, radius = 300,
    -- pickMaxStock absent → nil
})

ctld_test.assert(not zNoPickup:hasPickup(), "zone sans pickup : hasPickup() == false")
ctld_test.assert(not zNoPickup:consumeStock(1), "zone sans pickup : consumeStock retourne false")

ctld_test.finish()
