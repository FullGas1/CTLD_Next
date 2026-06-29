---@diagnostic disable
-- ============================================================
-- U-15 : CTLDBeaconManager _buildFreqPools
-- Module  : M2 (src/CTLD_beacon.lua)
-- Objectif:
--   - Les pools VHF/UHF/FM sont non vides après init
--   - Aucune fréquence NDB connue dans le pool VHF
--   - Pool UHF : toutes les fréquences < 399 MHz (399 000 000 Hz)
--   - Pool FM  : fréquences dans la plage attendue
-- Note    : on appelle _buildFreqPools directement sur une instance
--           légère (sans world.addEventHandler).
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

ctld_test.start("U-15", "CTLDBeaconManager _buildFreqPools")

-- Construire une instance légère et appeler _buildFreqPools manuellement
local mgr = setmetatable({}, CTLDBeaconManager)
mgr._freeVHF = {}
mgr._usedVHF = {}
mgr._freeUHF = {}
mgr._usedUHF = {}
mgr._freeFM  = {}
mgr._usedFM  = {}
mgr:_buildFreqPools()

-- ---- VHF pool ----
ctld_test.assert(#mgr._freeVHF > 0, "pool VHF non vide")

-- Construire le set des NDB (en Hz) pour vérification
local ndbSet = {}
for _, kHz in ipairs(CTLDBeaconManager._ndbSkip) do
    ndbSet[kHz * 1000] = true
end

local vhfHasNDB = false
for _, f in ipairs(mgr._freeVHF) do
    if ndbSet[f] then vhfHasNDB = true; break end
end
ctld_test.assert(not vhfHasNDB, "pool VHF ne contient aucune fréquence NDB skippée")

-- Toutes les fréquences VHF dans la plage 200–1250 kHz
local vhfInRange = true
for _, f in ipairs(mgr._freeVHF) do
    if f < 200000 or f > 1250000 then vhfInRange = false; break end
end
ctld_test.assert(vhfInRange, "toutes les fréquences VHF dans [200 kHz, 1250 kHz]")

-- ---- UHF pool ----
ctld_test.assert(#mgr._freeUHF > 0, "pool UHF non vide")

-- Toutes les fréquences UHF < 399 MHz
local uhfBelowLimit = true
for _, f in ipairs(mgr._freeUHF) do
    if f >= 399000000 then uhfBelowLimit = false; break end
end
ctld_test.assert(uhfBelowLimit, "pool UHF : toutes les fréquences < 399 MHz")

-- Fréquence minimale UHF >= 220 MHz
local uhfAboveMin = true
for _, f in ipairs(mgr._freeUHF) do
    if f < 220000000 then uhfAboveMin = false; break end
end
ctld_test.assert(uhfAboveMin, "pool UHF : toutes les fréquences >= 220 MHz")

-- Pas de doublon dans UHF
local uhfSeen = {}
local uhfNoDup = true
for _, f in ipairs(mgr._freeUHF) do
    if uhfSeen[f] then uhfNoDup = false; break end
    uhfSeen[f] = true
end
ctld_test.assert(uhfNoDup, "pool UHF : pas de doublon")

-- ---- FM pool ----
ctld_test.assert(#mgr._freeFM > 0, "pool FM non vide")

-- Toutes les fréquences FM dans la plage 30–76 MHz (formule source)
local fmInRange = true
for _, f in ipairs(mgr._freeFM) do
    if f < 30000000 or f > 76000000 then fmInRange = false; break end
end
ctld_test.assert(fmInRange, "toutes les fréquences FM dans [30, 76] MHz")

ctld_test.finish()
