---@diagnostic disable
-- ============================================================
-- U-59 : ctld.MenuManager — _sortByOrder
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: tri ascendant par order, sans-order → fin, stable
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-59", "ctld.MenuManager _sortByOrder")

-- T1: order ascendant — insertion order 30/10/20 → résultat 10/20/30
local nodes = {
    { name = "C", order = 30 },
    { name = "A", order = 10 },
    { name = "B", order = 20 },
}
local sorted = ctld.MenuManager:_sortByOrder(nodes)
ctld_test.assertEqual(sorted[1].name, "A", "T1a: premier = A (order 10)")
ctld_test.assertEqual(sorted[2].name, "B", "T1b: deuxième = B (order 20)")
ctld_test.assertEqual(sorted[3].name, "C", "T1c: troisième = C (order 30)")

-- T2: nœud sans order → placé en dernière position
local nodes2 = {
    { name = "X", order = 5 },
    { name = "Y" },            -- no order → math.huge
    { name = "Z", order = 10 },
}
local sorted2 = ctld.MenuManager:_sortByOrder(nodes2)
ctld_test.assertEqual(sorted2[1].name, "X", "T2a: X (order 5) en premier")
ctld_test.assertEqual(sorted2[2].name, "Z", "T2b: Z (order 10) en second")
ctld_test.assertEqual(sorted2[3].name, "Y", "T2c: Y (sans order) en dernier")

-- T3: liste vide → retourne {}
local sorted3 = ctld.MenuManager:_sortByOrder({})
ctld_test.assertEqual(#sorted3, 0, "T3: liste vide retourne table vide")

ctld_test.finish()
