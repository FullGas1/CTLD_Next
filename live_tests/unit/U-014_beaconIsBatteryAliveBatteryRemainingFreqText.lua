---@diagnostic disable
-- ============================================================
-- U-14 : CTLDBeacon isBatteryAlive / batteryRemaining / freqText
-- Module  : M2 (src/CTLD_beacon.lua)
-- Objectif: Tester les méthodes de consultation de la batterie
--           et le formattage texte des fréquences.
-- Note    : timer.getTime() est disponible en mission DCS (Witchcraft).
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

ctld_test.start("U-14", "CTLDBeacon isBatteryAlive / batteryRemaining / freqText")

local now = timer.getTime()

-- ---- Batterie infinie (batteryEndTime = -1) ----
local beaconInfinite = CTLDBeacon:new({
    beaconName    = "TestBeaconInfinite",
    name          = "Beacon FOB #1",
    coalitionId   = 2,
    position      = { x = 1000, y = 0, z = 2000 },
    vhfGroupName  = "vhf_grp_inf",
    uhfGroupName  = "uhf_grp_inf",
    fmGroupName   = "fm_grp_inf",
    vhf           = 245000,      -- 245 kHz
    uhf           = 350500000,   -- 350.5 MHz
    fm            = 45200000,    -- 45.2 MHz
    batteryEndTime = -1,
    spawnTime     = timer.getAbsTime(),
    isFOB         = true,
})

ctld_test.assert(beaconInfinite:isBatteryAlive(), "batterie infinie : isBatteryAlive == true")
ctld_test.assertEqual(beaconInfinite:batteryRemaining(), math.huge,
    "batterie infinie : batteryRemaining == math.huge")

-- freqText format attendu : "245.00 kHz - 350.50 / 45.20 MHz"
local txt = beaconInfinite:freqText()
ctld_test.assertNotNil(txt, "freqText() retourne une chaîne non-nil")
ctld_test.assert(txt:find("245.00 kHz") ~= nil,  "freqText contient '245.00 kHz'")
ctld_test.assert(txt:find("350.50") ~= nil,       "freqText contient '350.50'")
ctld_test.assert(txt:find("45.20 MHz") ~= nil,    "freqText contient '45.20 MHz'")

-- ---- Batterie finie, encore vivante ----
local beaconAlive = CTLDBeacon:new({
    beaconName    = "TestBeaconAlive",
    name          = "Beacon #2",
    coalitionId   = 2,
    position      = { x = 0, y = 0, z = 0 },
    vhfGroupName  = "vhf_grp_a",
    uhfGroupName  = "uhf_grp_a",
    fmGroupName   = "fm_grp_a",
    vhf           = 300000,
    uhf           = 250000000,
    fm            = 40000000,
    batteryEndTime = now + 1800,  -- expire dans 30 min
    spawnTime     = timer.getAbsTime(),
    isFOB         = false,
})

ctld_test.assert(beaconAlive:isBatteryAlive(), "batterie finie vivante : isBatteryAlive == true")
local rem = beaconAlive:batteryRemaining()
ctld_test.assert(rem > 0 and rem <= 1800, "batteryRemaining dans [0, 1800] s")

-- ---- Batterie expirée ----
local beaconDead = CTLDBeacon:new({
    beaconName    = "TestBeaconDead",
    name          = "Beacon #3",
    coalitionId   = 1,
    position      = { x = 0, y = 0, z = 0 },
    vhfGroupName  = "vhf_grp_d",
    uhfGroupName  = "uhf_grp_d",
    fmGroupName   = "fm_grp_d",
    vhf           = 300000,
    uhf           = 250000000,
    fm            = 40000000,
    batteryEndTime = now - 60,  -- expirée il y a 60 s
    spawnTime     = timer.getAbsTime() - 1920,
    isFOB         = false,
})

ctld_test.assert(not beaconDead:isBatteryAlive(), "batterie expirée : isBatteryAlive == false")
ctld_test.assertEqual(beaconDead:batteryRemaining(), 0,
    "batterie expirée : batteryRemaining == 0")

ctld_test.finish()
