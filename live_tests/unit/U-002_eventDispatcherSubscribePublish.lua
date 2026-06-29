---@diagnostic disable
-- ============================================================
-- U-02 : EventDispatcher — subscribe + publish
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Le callback souscrit est appelé avec le bon payload
--           lors d'un publish.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("U-02", "EventDispatcher — subscribe + publish")

-- Reset singleton pour état propre
EventDispatcher._instance = nil
local ed = EventDispatcher.getInstance()

-- Test 1 : callback basique reçoit le payload
local received = nil
ed:subscribe("TestEvent", function(p) received = p end)
ed:publish("TestEvent", { value = 42 })

ctld_test.assertNotNil(received, "callback appelé après publish")
ctld_test.assertEqual(received.value, 42, "payload.value == 42")

-- Test 2 : callback non déclenché pour un autre event
local received2 = nil
ed:subscribe("OtherEvent", function(p) received2 = p end)
ed:publish("TestEvent", { value = 99 })

ctld_test.assertNil(received2, "callback OtherEvent non déclenché par TestEvent")

-- Test 3 : plusieurs callbacks sur le même event
local countA, countB = 0, 0
ed:subscribe("MultiEvent", function() countA = countA + 1 end)
ed:subscribe("MultiEvent", function() countB = countB + 1 end)
ed:publish("MultiEvent", {})

ctld_test.assertEqual(countA, 1, "premier callback appelé une fois")
ctld_test.assertEqual(countB, 1, "second callback appelé une fois")

-- Test 4 : publish sans subscriber → pas d'erreur
local ok = pcall(function() ed:publish("NoSubscriber", { x = 1 }) end)
ctld_test.assert(ok, "publish sur event sans subscriber ne crash pas")

ctld_test.finish()
