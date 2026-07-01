---@diagnostic disable
-- ============================================================
-- U-09 : CTLDZoneManager._parseTRZ — formats invalides
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Le parser strict retourne nil + message d'erreur pour
--           tout format non conforme au schéma 5 champs obligatoires :
--   TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("U-09", "CTLDZoneManager._parseTRZ — formats invalides")

local zm = setmetatable({}, CTLDZoneManager)

-- 1. Préfixe incorrect → "not a TRZ"
local r1, e1 = zm:_parseTRZ("LGZ_alpha_B_10_nil_0")
ctld_test.assertNil(r1,    "LGZ_... : résultat nil")
ctld_test.assertNotNil(e1, "LGZ_... : erreur non-nil")
ctld_test.assert(e1:find("not a TRZ") ~= nil, "LGZ_... : erreur contient 'not a TRZ'")

-- 2. Préfixe PKZ → nil
local r2, e2 = zm:_parseTRZ("PKZ_alpha_B_10_nil_0")
ctld_test.assertNil(r2,    "PKZ_... : résultat nil")
ctld_test.assertNotNil(e2, "PKZ_... : erreur non-nil")

-- 3. Juste "TRZ" sans zoneName → "missing zoneName"
local r3, e3 = zm:_parseTRZ("TRZ")
ctld_test.assertNil(r3,    "TRZ seul : résultat nil")
ctld_test.assertNotNil(e3, "TRZ seul : erreur non-nil")
ctld_test.assert(e3:find("zoneName") ~= nil, "TRZ seul : erreur mentionne 'zoneName'")

-- 4. "TRZ_" (zoneName vide) → nil
local r4, e4 = zm:_parseTRZ("TRZ_")
ctld_test.assertNil(r4, "TRZ_ : résultat nil")

-- 5. Nom vide → nil
local r5, e5 = zm:_parseTRZ("")
ctld_test.assertNil(r5, "chaîne vide : résultat nil")

-- 6. Pas de préfixe TRZ → nil
local r6, e6 = zm:_parseTRZ("alpha_B_10_nil_0")
ctld_test.assertNil(r6, "sans préfixe TRZ : résultat nil")

-- 7. Coalition manquante (ancien format 3 champs) → erreur
local r7, e7 = zm:_parseTRZ("TRZ_alpha")
ctld_test.assertNil(r7,    "TRZ_alpha (1 champ) : nil")
ctld_test.assertNotNil(e7, "TRZ_alpha : erreur non-nil")
ctld_test.assert(e7:find("coalition") ~= nil, "TRZ_alpha : erreur mentionne 'coalition'")

-- 8. Ancien format 2 champs (TRZ_alpha_B) → coalition ok mais stock manquant → erreur
local r8, e8 = zm:_parseTRZ("TRZ_alpha_B")
ctld_test.assertNil(r8,    "TRZ_alpha_B (2 champs) : nil")
ctld_test.assertNotNil(e8, "TRZ_alpha_B : erreur non-nil")
ctld_test.assert(e8:find("stock") ~= nil, "TRZ_alpha_B : erreur mentionne 'stock'")

-- 9. Coalition invalide (X) → erreur "invalid coalition"
local r9, e9 = zm:_parseTRZ("TRZ_alpha_X_10_nil_0")
ctld_test.assertNil(r9,    "coalition X : nil")
ctld_test.assertNotNil(e9, "coalition X : erreur non-nil")
ctld_test.assert(e9:find("coalition") ~= nil, "coalition X : erreur mentionne 'coalition'")

-- 10. Stock hors plage (1000) → erreur "invalid stock"
local r10, e10 = zm:_parseTRZ("TRZ_alpha_B_1000_nil_0")
ctld_test.assertNil(r10,    "stock 1000 : nil")
ctld_test.assertNotNil(e10, "stock 1000 : erreur non-nil")
ctld_test.assert(e10:find("stock") ~= nil, "stock 1000 : erreur mentionne 'stock'")

-- 11. Stock négatif → erreur
local r11, e11 = zm:_parseTRZ("TRZ_alpha_B_-5_nil_0")
ctld_test.assertNil(r11,    "stock -5 : nil")
ctld_test.assertNotNil(e11, "stock -5 : erreur non-nil")

-- 12. Flag numérique (pas un nom de flag) → erreur "flag must be a string"
local r12, e12 = zm:_parseTRZ("TRZ_alpha_B_10_42_0")
ctld_test.assertNil(r12,    "flag=42 (nombre) : nil")
ctld_test.assertNotNil(e12, "flag=42 : erreur non-nil")
ctld_test.assert(e12:find("string") ~= nil, "flag=42 : erreur mentionne 'string'")

-- 13. Target manquant (4 champs seulement) → erreur
local r13, e13 = zm:_parseTRZ("TRZ_alpha_B_10_nil")
ctld_test.assertNil(r13,    "target manquant : nil")
ctld_test.assertNotNil(e13, "target manquant : erreur non-nil")
ctld_test.assert(e13:find("target") ~= nil, "target manquant : erreur mentionne 'target'")

-- 14. Target négatif → erreur
local r14, e14 = zm:_parseTRZ("TRZ_alpha_B_10_nil_-1")
ctld_test.assertNil(r14,    "target -1 : nil")
ctld_test.assertNotNil(e14, "target -1 : erreur non-nil")
ctld_test.assert(e14:find("target") ~= nil, "target -1 : erreur mentionne 'target'")

-- 15. zoneName = mot réservé "nil" → erreur
local r15, e15 = zm:_parseTRZ("TRZ_nil_B_10_nil_0")
ctld_test.assertNil(r15,    "zoneName='nil' (réservé) : nil")
ctld_test.assertNotNil(e15, "zoneName='nil' : erreur non-nil")
ctld_test.assert(e15:find("reserved") ~= nil, "zoneName='nil' : erreur mentionne 'reserved'")

-- 16. zoneName = mot réservé "A" → erreur
local r16, e16 = zm:_parseTRZ("TRZ_A_B_10_nil_0")
ctld_test.assertNil(r16,    "zoneName='A' (réservé) : nil")
ctld_test.assertNotNil(e16, "zoneName='A' : erreur non-nil")

ctld_test.finish()
