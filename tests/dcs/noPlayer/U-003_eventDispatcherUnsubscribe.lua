---@diagnostic disable
-- ============================================================
-- U-03 : EventDispatcher — unsubscribe
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Après unsubscribe, le callback n'est plus appelé.
--           Vérifie également que les autres callbacks sur le même
--           event ne sont pas affectés.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("U-03", "EventDispatcher — unsubscribe")

EventDispatcher._instance = nil
local ed = EventDispatcher.getInstance()

-- Test 1 : callback non appelé après unsubscribe
local callCountA = 0
local cbA = function() callCountA = callCountA + 1 end

ed:subscribe("EvA", cbA)
ed:publish("EvA", {})
ctld_test.assertEqual(callCountA, 1, "callback appelé avant unsubscribe")

ed:unsubscribe("EvA", cbA)
ed:publish("EvA", {})
ctld_test.assertEqual(callCountA, 1, "callback non appelé après unsubscribe")

-- Test 2 : unsubscribe n'affecte pas les autres callbacks
local callCountB = 0
local cbB = function() callCountB = callCountB + 1 end
local cbC_count = 0
local cbC = function() cbC_count = cbC_count + 1 end

ed:subscribe("EvB", cbB)
ed:subscribe("EvB", cbC)
ed:unsubscribe("EvB", cbB)
ed:publish("EvB", {})

ctld_test.assertEqual(callCountB, 0, "cbB non appelé après unsubscribe")
ctld_test.assertEqual(cbC_count,  1, "cbC toujours appelé (non affecté)")

-- Test 3 : unsubscribe sur event inexistant → pas d'erreur
local ok = pcall(function() ed:unsubscribe("NonExistentEvent", cbA) end)
ctld_test.assert(ok, "unsubscribe event inexistant ne crash pas")

-- Test 4 : unsubscribe sur callback non enregistré → pas d'erreur
local cbD = function() end
ed:subscribe("EvD", cbA)
local ok2 = pcall(function() ed:unsubscribe("EvD", cbD) end)  -- cbD jamais souscrit à EvD
ctld_test.assert(ok2, "unsubscribe callback non enregistré ne crash pas")

ctld_test.finish()
