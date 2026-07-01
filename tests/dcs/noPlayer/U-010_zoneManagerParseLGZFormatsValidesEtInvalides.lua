---@diagnostic disable
-- ============================================================
-- U-10 : CTLDZoneManager._parseLGZ — formats valides et invalides
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Parser LGZ sur noms bien formés (coalition R/B/N et absent)
--           et mal formés (non-LGZ).
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("U-10", "CTLDZoneManager._parseLGZ — formats valides et invalides")

local zm = setmetatable({}, CTLDZoneManager)

-- Formats valides ---

-- 1. Minimal sans coalition : LGZ_base
local r1 = zm:_parseLGZ("LGZ_base")
ctld_test.assertNotNil(r1,                "LGZ_base : résultat non-nil")
ctld_test.assertEqual(r1.name, "base",    "LGZ_base : name == 'base'")
ctld_test.assertEqual(r1.coalition, 0,    "LGZ_base : coalition == 0")

-- 2. Coalition BLUE : LGZ_farp_B
local r2 = zm:_parseLGZ("LGZ_farp_B")
ctld_test.assertNotNil(r2,                     "LGZ_farp_B : résultat non-nil")
ctld_test.assertEqual(r2.name, "farp",         "LGZ_farp_B : name == 'farp'")
ctld_test.assertEqual(r2.coalition, coalition.side.BLUE, "LGZ_farp_B : coalition BLUE")

-- 3. Coalition RED : LGZ_depot_R
local r3 = zm:_parseLGZ("LGZ_depot_R")
ctld_test.assertNotNil(r3, "LGZ_depot_R : résultat non-nil")
ctld_test.assertEqual(r3.coalition, coalition.side.RED, "LGZ_depot_R : coalition RED")

-- 4. Coalition NEUTRAL : LGZ_supply_N
local r4 = zm:_parseLGZ("LGZ_supply_N")
ctld_test.assertNotNil(r4, "LGZ_supply_N : résultat non-nil")
ctld_test.assertEqual(r4.coalition, coalition.side.NEUTRAL, "LGZ_supply_N : coalition NEUTRAL")

-- Formats invalides ---

-- 5. Non-LGZ : TRZ_alpha_B → nil
local r5 = zm:_parseLGZ("TRZ_alpha_B")
ctld_test.assertNil(r5, "TRZ_alpha_B : résultat nil (non LGZ)")

-- 6. Préfixe quelconque : WPZ_x → nil
local r6 = zm:_parseLGZ("WPZ_x")
ctld_test.assertNil(r6, "WPZ_x : résultat nil")

-- 7. Chaîne vide → nil
local r7 = zm:_parseLGZ("")
ctld_test.assertNil(r7, "chaîne vide : résultat nil")

-- 8. LGZ_ sans nom : toujours retourner une table (name = nil acceptable)
--    La convention source : parts[2] peut être nil mais le retour n'est pas nil.
--    On vérifie seulement que ça ne crash pas.
local ok = pcall(function() zm:_parseLGZ("LGZ_") end)
ctld_test.assert(ok, "LGZ_ seul ne crash pas")

ctld_test.finish()
