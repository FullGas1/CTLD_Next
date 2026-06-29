---@diagnostic disable
-- ============================================================
-- U-08 : CTLDZoneManager._parseTRZ — formats valides
-- Module  : M1 (src/CTLD_zone.lua)
-- Objectif: Parser TRZ strict 5 champs :
--   TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>
--   Cas testés :
--   1. Pickup limité        : TRZ_alpha_B_10_nil_0
--   2. Pickup illimité      : TRZ_bravo_A_999_nil_0
--   3. Extract seule        : TRZ_charlie_R_0_obj1_0
--   4. Extract avec cible   : TRZ_delta_B_0_win_50
--   5. Mixte (pickup+obj)   : TRZ_echo_N_20_rescue_100
--   6. Coalition all        : TRZ_foxtrot_A_5_nil_0
-- Méthode testée en isolation : instance temporaire, pas de singleton.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")

ctld_test.start("U-08", "CTLDZoneManager._parseTRZ — formats valides")

-- Créer une instance temporaire (sans init() pour éviter les appels DCS)
local zm = setmetatable({}, CTLDZoneManager)

-- 1. Pickup limité : TRZ_alpha_B_10_nil_0
local r1, e1 = zm:_parseTRZ("TRZ_alpha_B_10_nil_0")
ctld_test.assertNotNil(r1,                  "TRZ_alpha_B_10_nil_0 : résultat non-nil")
ctld_test.assertNil(e1,                     "TRZ_alpha_B_10_nil_0 : pas d'erreur")
ctld_test.assertEqual(r1.zoneName,   "alpha", "TRZ_alpha_B_10_nil_0 : zoneName == 'alpha'")
ctld_test.assertEqual(r1.coalition,  coalition.side.BLUE, "TRZ_alpha_B_10_nil_0 : coalition BLUE")
ctld_test.assertEqual(r1.pickMaxStock, 10,   "TRZ_alpha_B_10_nil_0 : pickMaxStock == 10")
ctld_test.assertNil(r1.objectiveFlag,        "TRZ_alpha_B_10_nil_0 : objectiveFlag nil (flag='nil')")
ctld_test.assertNil(r1.objectiveTarget,      "TRZ_alpha_B_10_nil_0 : objectiveTarget nil (target=0)")

-- 2. Pickup illimité : TRZ_bravo_A_999_nil_0
local r2, e2 = zm:_parseTRZ("TRZ_bravo_A_999_nil_0")
ctld_test.assertNotNil(r2,                  "TRZ_bravo_A_999_nil_0 : résultat non-nil")
ctld_test.assertNil(e2,                     "TRZ_bravo_A_999_nil_0 : pas d'erreur")
ctld_test.assertEqual(r2.zoneName,  "bravo", "TRZ_bravo_A_999_nil_0 : zoneName == 'bravo'")
ctld_test.assertEqual(r2.coalition, 0,       "TRZ_bravo_A_999_nil_0 : coalition == 0 (all)")
ctld_test.assertEqual(r2.pickMaxStock, 0,    "TRZ_bravo_A_999_nil_0 : pickMaxStock == 0 (illimité interne)")
ctld_test.assertNil(r2.objectiveFlag,        "TRZ_bravo_A_999_nil_0 : objectiveFlag nil")
ctld_test.assertNil(r2.objectiveTarget,      "TRZ_bravo_A_999_nil_0 : objectiveTarget nil")

-- 3. Extract seule (pas de pickup) : TRZ_charlie_R_0_obj1_0
local r3, e3 = zm:_parseTRZ("TRZ_charlie_R_0_obj1_0")
ctld_test.assertNotNil(r3,                  "TRZ_charlie_R_0_obj1_0 : résultat non-nil")
ctld_test.assertNil(e3,                     "TRZ_charlie_R_0_obj1_0 : pas d'erreur")
ctld_test.assertEqual(r3.zoneName, "charlie","TRZ_charlie_R_0_obj1_0 : zoneName == 'charlie'")
ctld_test.assertEqual(r3.coalition, coalition.side.RED, "TRZ_charlie_R_0_obj1_0 : coalition RED")
ctld_test.assertNil(r3.pickMaxStock,         "TRZ_charlie_R_0_obj1_0 : pickMaxStock nil (stock=0 → pas de pickup)")
ctld_test.assertEqual(r3.objectiveFlag, "obj1","TRZ_charlie_R_0_obj1_0 : objectiveFlag == 'obj1'")
ctld_test.assertNil(r3.objectiveTarget,      "TRZ_charlie_R_0_obj1_0 : objectiveTarget nil (target=0)")

-- 4. Extract avec cible : TRZ_delta_B_0_win_50
local r4, e4 = zm:_parseTRZ("TRZ_delta_B_0_win_50")
ctld_test.assertNotNil(r4,                  "TRZ_delta_B_0_win_50 : résultat non-nil")
ctld_test.assertNil(e4,                     "TRZ_delta_B_0_win_50 : pas d'erreur")
ctld_test.assertEqual(r4.zoneName,  "delta", "TRZ_delta_B_0_win_50 : zoneName == 'delta'")
ctld_test.assertEqual(r4.coalition, coalition.side.BLUE, "TRZ_delta_B_0_win_50 : coalition BLUE")
ctld_test.assertNil(r4.pickMaxStock,         "TRZ_delta_B_0_win_50 : pickMaxStock nil (pas de pickup)")
ctld_test.assertEqual(r4.objectiveFlag,  "win","TRZ_delta_B_0_win_50 : objectiveFlag == 'win'")
ctld_test.assertEqual(r4.objectiveTarget, 50,  "TRZ_delta_B_0_win_50 : objectiveTarget == 50")

-- 5. Mixte pickup + extract : TRZ_echo_N_20_rescue_100
local r5, e5 = zm:_parseTRZ("TRZ_echo_N_20_rescue_100")
ctld_test.assertNotNil(r5,                  "TRZ_echo_N_20_rescue_100 : résultat non-nil")
ctld_test.assertNil(e5,                     "TRZ_echo_N_20_rescue_100 : pas d'erreur")
ctld_test.assertEqual(r5.zoneName,  "echo",  "TRZ_echo_N_20_rescue_100 : zoneName == 'echo'")
ctld_test.assertEqual(r5.coalition, coalition.side.NEUTRAL, "TRZ_echo_N_20_rescue_100 : coalition NEUTRAL")
ctld_test.assertEqual(r5.pickMaxStock,  20,  "TRZ_echo_N_20_rescue_100 : pickMaxStock == 20")
ctld_test.assertEqual(r5.objectiveFlag, "rescue","TRZ_echo_N_20_rescue_100 : objectiveFlag == 'rescue'")
ctld_test.assertEqual(r5.objectiveTarget, 100,"TRZ_echo_N_20_rescue_100 : objectiveTarget == 100")

-- 6. Coalition all (A) : TRZ_foxtrot_A_5_nil_0
local r6, e6 = zm:_parseTRZ("TRZ_foxtrot_A_5_nil_0")
ctld_test.assertNotNil(r6,                  "TRZ_foxtrot_A_5_nil_0 : résultat non-nil")
ctld_test.assertNil(e6,                     "TRZ_foxtrot_A_5_nil_0 : pas d'erreur")
ctld_test.assertEqual(r6.coalition, 0,       "TRZ_foxtrot_A_5_nil_0 : coalition == 0 (all)")
ctld_test.assertEqual(r6.pickMaxStock, 5,    "TRZ_foxtrot_A_5_nil_0 : pickMaxStock == 5")
ctld_test.assertNil(r6.objectiveFlag,        "TRZ_foxtrot_A_5_nil_0 : objectiveFlag nil")

ctld_test.finish()
