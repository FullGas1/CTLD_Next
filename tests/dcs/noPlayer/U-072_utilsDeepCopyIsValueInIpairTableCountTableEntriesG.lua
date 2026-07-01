---@diagnostic disable
-- ============================================================
-- U-72 : ctld.utils — deepCopy, isValueInIpairTable, countTableEntries, getNextUniqId
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: copie indépendante, lookup, count, compteur monotone
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-72", "ctld.utils deepCopy isValueInIpairTable countTableEntries getNextUniqId")

-- ── deepCopy ──────────────────────────────────────────────────
local orig = { a = 1, b = { c = 2, d = { 3, 4 } } }
local copy = ctld.utils.deepCopy("t", orig)

ctld_test.assert(copy ~= orig,                    "T1a: copie est un objet différent")
ctld_test.assertEqual(copy.a, 1,                  "T1b: copy.a == 1")
ctld_test.assertEqual(copy.b.c, 2,                "T1c: copy.b.c == 2")
ctld_test.assert(copy.b ~= orig.b,                "T1d: sous-table copiée indépendamment")

-- mutation de l'original n'affecte pas la copie
orig.a = 99
ctld_test.assertEqual(copy.a, 1,                  "T1e: copy.a toujours 1 après mutation original")

-- nil guard
ctld_test.assertNil(ctld.utils.deepCopy("t", nil), "T1f: deepCopy(nil) → nil")

-- ── isValueInIpairTable ───────────────────────────────────────
local tab = {10, 20, 30}
ctld_test.assert(    ctld.utils.isValueInIpairTable("t", tab, 20),   "T2a: 20 présent → true")
ctld_test.assert(not ctld.utils.isValueInIpairTable("t", tab, 99),   "T2b: 99 absent → false")
ctld_test.assert(not ctld.utils.isValueInIpairTable("t", nil, 10),   "T2c: table nil → false")

-- ── countTableEntries ─────────────────────────────────────────
ctld_test.assertEqual(ctld.utils.countTableEntries("t", {a=1,b=2,c=3}), 3, "T3a: 3 clés string → 3")
ctld_test.assertEqual(ctld.utils.countTableEntries("t", {1,2,3,4}),     4, "T3b: 4 clés ipairs → 4")
ctld_test.assertEqual(ctld.utils.countTableEntries("t", {}),            0, "T3c: table vide → 0")
ctld_test.assertEqual(ctld.utils.countTableEntries("t", "notatable"),   0, "T3d: non-table → 0")

-- ── getNextUniqId ─────────────────────────────────────────────
local id1 = ctld.utils.getNextUniqId()
local id2 = ctld.utils.getNextUniqId()
local id3 = ctld.utils.getNextUniqId()
ctld_test.assert(type(id1) == "number",  "T4a: getNextUniqId retourne un number")
ctld_test.assert(id2 == id1 + 1,         "T4b: id2 == id1+1 (monotone)")
ctld_test.assert(id3 == id2 + 1,         "T4c: id3 == id2+1 (monotone)")

ctld_test.finish()
