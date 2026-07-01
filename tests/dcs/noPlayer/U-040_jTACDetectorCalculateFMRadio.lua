---@diagnostic disable
-- ============================================================
-- U-40 : CTLDJTACDetector.calculateFMRadio
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

ctld_test.start("U-40", "CTLDJTACDetector.calculateFMRadio")

-- Formula: freq = 30 + floor((code-1000)/100) + ((code-1000) mod 100) * 0.05
-- code=1111: laserB=floor(111/100)=1, laserCD=111-100=11, freq=30+1+11*0.05=31+0.55=31.55
local r1 = CTLDJTACDetector.calculateFMRadio("JTAC1", 1111)
ctld_test.assertNotNil(r1, "code 1111 retourne table")
ctld_test.assertEqual(r1.name, "JTAC1",  "name == JTAC1")
ctld_test.assertEqual(r1.mod,  "fm",     "mod == fm")
ctld_test.assertEqual(r1.freq, "31.55",  "freq 1111 == 31.55")

-- code=1688: laserB=floor(688/100)=6, laserCD=688-600=88, freq=30+6+88*0.05=36+4.4=40.4
local r2 = CTLDJTACDetector.calculateFMRadio("JTAC2", 1688)
ctld_test.assertNotNil(r2, "code 1688 retourne table")
ctld_test.assertEqual(r2.freq, "40.4",   "freq 1688 == 40.4")

-- Limits: 1110 → nil (trop bas), 1689 → nil (trop haut)
ctld_test.assertNil(CTLDJTACDetector.calculateFMRadio("G", 1110), "code 1110 → nil (< 1111)")
ctld_test.assertNil(CTLDJTACDetector.calculateFMRadio("G", 1689), "code 1689 → nil (> 1688)")
ctld_test.assertNil(CTLDJTACDetector.calculateFMRadio("G", nil),  "code nil → nil")

-- code=1200: laserB=2, laserCD=0, freq=30+2+0=32
local r3 = CTLDJTACDetector.calculateFMRadio("JTAC3", 1200)
ctld_test.assertEqual(r3.freq, "32",     "freq 1200 == 32")

-- code=1155: laserB=1, laserCD=55, freq=30+1+55*0.05=31+2.75=33.75
local r4 = CTLDJTACDetector.calculateFMRadio("JTAC4", 1155)
ctld_test.assertEqual(r4.freq, "33.75",  "freq 1155 == 33.75")

ctld_test.finish()
