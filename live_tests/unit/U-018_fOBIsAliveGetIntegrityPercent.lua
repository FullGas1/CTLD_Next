---@diagnostic disable
-- ============================================================
-- U-18 : CTLDFOB isAlive / getIntegrityPercent
-- Module  : M4 (src/CTLD_fob.lua)
-- Objectif: Tester les seuils d'intégrité :
--   - 0 objet scène → isAlive = false, integrity = 0
--   - 1 objet vivant sur 3 → isAlive = true, integrity ≈ 0.33
--   - Tous vivants → isAlive = true, integrity = 1.0
-- On utilise des stubs d'objets DCS avec isExist() contrôlable.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

-- CTLD_fob.lua a besoin de CTLDZoneManager, CTLDBeaconManager, etc.
-- On les charge ou on crée des stubs suffisants.
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

-- Stub minimal CTLDSceneManager pour éviter crash au chargement de CTLD_fob.lua
if not CTLDSceneManager then
    CTLDSceneManager = { getInstance = function() return {} end }
end
if not CTLDCrateManager then
    CTLDCrateManager = { getInstance = function() return {} end }
end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_fob.lua")

ctld_test.start("U-18", "CTLDFOB isAlive / getIntegrityPercent")

-- Helper : stub objet DCS
local function makeObj(alive)
    return { isExist = function() return alive end, getName = function() return "stub" end }
end

-- ---- Cas 1 : aucun objet scène ----
local fob0 = CTLDFOB:new({
    fobId      = "fob_000",
    name       = "FOB Test 0",
    coalitionId = 2,
    countryId  = 2,
    position   = { x = 0, y = 0, z = 0 },
    sceneObjects = {},
})

ctld_test.assert(not fob0:isAlive(), "0 objet : isAlive == false")
ctld_test.assertEqual(fob0:getIntegrityPercent(), 0, "0 objet : integrity == 0")

-- ---- Cas 2 : tous vivants (3/3) ----
local fob3 = CTLDFOB:new({
    fobId       = "fob_001",
    name        = "FOB Test All",
    coalitionId = 2,
    countryId   = 2,
    position    = { x = 0, y = 0, z = 0 },
    sceneObjects = { makeObj(true), makeObj(true), makeObj(true) },
})

ctld_test.assert(fob3:isAlive(), "3/3 vivants : isAlive == true")
ctld_test.assertEqual(fob3:getIntegrityPercent(), 1.0, "3/3 vivants : integrity == 1.0")

-- ---- Cas 3 : 1 vivant sur 3 ----
local fob1 = CTLDFOB:new({
    fobId       = "fob_002",
    name        = "FOB Test Partial",
    coalitionId = 2,
    countryId   = 2,
    position    = { x = 0, y = 0, z = 0 },
    sceneObjects = { makeObj(false), makeObj(false), makeObj(true) },
})

ctld_test.assert(fob1:isAlive(), "1/3 vivant : isAlive == true")
local integ1 = fob1:getIntegrityPercent()
ctld_test.assert(math.abs(integ1 - (1/3)) < 0.001,
    string.format("1/3 vivant : integrity ≈ 0.333 (got %.4f)", integ1))

-- ---- Cas 4 : tous détruits (0/3) ----
local fob0b = CTLDFOB:new({
    fobId       = "fob_003",
    name        = "FOB Destroyed",
    coalitionId = 1,
    countryId   = 1,
    position    = { x = 0, y = 0, z = 0 },
    sceneObjects = { makeObj(false), makeObj(false), makeObj(false) },
})

ctld_test.assert(not fob0b:isAlive(), "0/3 vivants : isAlive == false")
ctld_test.assertEqual(fob0b:getIntegrityPercent(), 0, "0/3 vivants : integrity == 0")

-- ---- Cas 5 : 2 vivants sur 4 ----
local fob2 = CTLDFOB:new({
    fobId       = "fob_004",
    name        = "FOB Half",
    coalitionId = 2,
    countryId   = 2,
    position    = { x = 0, y = 0, z = 0 },
    sceneObjects = { makeObj(true), makeObj(false), makeObj(true), makeObj(false) },
})

ctld_test.assert(fob2:isAlive(), "2/4 vivants : isAlive == true")
ctld_test.assertEqual(fob2:getIntegrityPercent(), 0.5, "2/4 vivants : integrity == 0.5")

ctld_test.finish()
