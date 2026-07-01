---@diagnostic disable
-- ============================================================
-- U-25 : CTLDCrateAssemblyManager — _buildSpawnArrays géométrie
-- Module  : M6 (src/CTLD_aasystem.lua)
-- Objectif: Vérifier la géométrie de placement des pièces AA :
--   - _buildSpawnArrays retourne autant d'entrées que de parts × amounts
--   - positions et headings sont des nombres valides
--   - le nombre d'unités correspond à la somme des amounts du template
-- Test purement unitaire, pas d'API DCS requise.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_aasystem.lua")

ctld_test.start("U-25", "_buildSpawnArrays — géométrie spawn AA")

CTLDCrateAssemblyManager._instance = nil
EventDispatcher._instance          = nil
CTLDDCSEventBridge._instance       = nil

local mgr = CTLDCrateAssemblyManager.getInstance()

-- Utiliser le template KUB (2 parties, amounts simples : 1 launcher + 1 radar)
local tmpl = nil
for _, t in ipairs(CTLDCrateAssemblyManager.TEMPLATES) do
    if t.name == "KUB AA System" then tmpl = t break end
end
ctld_test.assertNotNil(tmpl, "template KUB trouvé")

-- Construire systemParts complet (tous les parts found)
local systemParts = {}
for _, part in ipairs(tmpl.parts) do
    systemParts[part.name] = {
        desc     = part.desc,
        launcher = part.launcher,
        amount   = part.amount,
        NoCrate  = part.NoCrate,
        found    = 1,
        required = 1,
        crates   = {},
    }
end

-- Origine fictive (sans DCS on doit mocker land.getHeight)
-- land.getHeight retourne 0 dans l'env de test
local origin = { x = 1000, y = 0, z = 2000 }

-- Mock heli (non utilisé dans _buildSpawnArrays pour KUB)
local fakeHeli = {}

local positions, types, headings = mgr:_buildSpawnArrays(tmpl, systemParts, origin, fakeHeli)

-- KUB : 2 parties, launcher (amount=nil → aaLaunchers=3), radar (amount=nil → 1)
-- launcher: aaLaunchers=3 → 3 positions
-- radar: amount non défini, pas launcher → 1 position
-- total = 3 + 1 = 4
local aaLaunchers = ctld.gs("aaLaunchers") or 3

ctld_test.assertNotNil(positions, "positions non-nil")
ctld_test.assertNotNil(types,     "types non-nil")
ctld_test.assertNotNil(headings,  "headings non-nil")
ctld_test.assertEqual(#positions, #types,    "#positions == #types")
ctld_test.assertEqual(#positions, #headings, "#positions == #headings")

local expectedTotal = aaLaunchers + 1  -- launcher×aaLaunchers + radar×1
ctld_test.assertEqual(#positions, expectedTotal,
    string.format("#positions == %d (aaLaunchers=%d + 1 radar)", expectedTotal, aaLaunchers))

-- Toutes les positions ont des coordonnées numériques
local allNumeric = true
for _, pos in ipairs(positions) do
    if type(pos.x) ~= "number" or type(pos.z) ~= "number" then
        allNumeric = false
    end
end
ctld_test.assert(allNumeric, "toutes les positions ont des coords x,z numériques")

-- Tous les types sont des strings non-vides
local allStrings = true
for _, t in ipairs(types) do
    if type(t) ~= "string" or #t == 0 then allStrings = false end
end
ctld_test.assert(allStrings, "tous les types sont des strings non-vides")

-- Tous les headings sont des nombres
local allHdgNum = true
for _, h in ipairs(headings) do
    if type(h) ~= "number" then allHdgNum = false end
end
ctld_test.assert(allHdgNum, "tous les headings sont des nombres")

-- Les positions sont différentes les unes des autres (pas de pile-up)
local unique = true
for i = 1, #positions do
    for j = i+1, #positions do
        local dx = positions[i].x - positions[j].x
        local dz = positions[i].z - positions[j].z
        if math.abs(dx) < 0.01 and math.abs(dz) < 0.01 then
            unique = false
        end
    end
end
ctld_test.assert(unique, "toutes les positions sont distinctes (pas de pile-up)")

-- Test NASAMS (3 parties, count=3, pas de NoCrate)
local tmplNasams = nil
for _, t in ipairs(CTLDCrateAssemblyManager.TEMPLATES) do
    if t.name == "NASAMS AA System" then tmplNasams = t break end
end
ctld_test.assertNotNil(tmplNasams, "template NASAMS trouvé")

local spNasams = {}
for _, part in ipairs(tmplNasams.parts) do
    spNasams[part.name] = { found = 1, required = 1, NoCrate = part.NoCrate,
        launcher = part.launcher, amount = part.amount, crates = {} }
end

local posN, typN, hdgN = mgr:_buildSpawnArrays(tmplNasams, spNasams, origin, fakeHeli)
-- NASAMS: launcher(aaLaunchers), radar(1), command post(1)
local expectedNasams = aaLaunchers + 1 + 1
ctld_test.assertEqual(#posN, expectedNasams,
    string.format("NASAMS: %d positions (launcher×%d + radar + CP)", expectedNasams, aaLaunchers))

ctld_test.finish()
