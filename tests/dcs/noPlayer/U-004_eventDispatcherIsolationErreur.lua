---@diagnostic disable
-- ============================================================
-- U-04 : EventDispatcher — isolation erreur
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Un callback qui throw ne doit pas empêcher l'exécution
--           des callbacks suivants sur le même event.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("U-04", "EventDispatcher — isolation erreur callback")

EventDispatcher._instance = nil
local ed = EventDispatcher.getInstance()

-- Enregistrer : cbGood1, cbBad (throw), cbGood2
local good1Called = false
local good2Called = false

ed:subscribe("IsoEvent", function(p)
    good1Called = true
end)

ed:subscribe("IsoEvent", function(p)
    error("intentional test error from cbBad")
end)

ed:subscribe("IsoEvent", function(p)
    good2Called = true
end)

-- publish ne doit pas propager l'erreur
local ok = pcall(function() ed:publish("IsoEvent", { x = 1 }) end)

ctld_test.assert(ok,          "publish ne crash pas même si un callback throw")
ctld_test.assert(good1Called, "callback avant le throw est bien appelé")
ctld_test.assert(good2Called, "callback après le throw est bien appelé")

-- Test 2 : deux erreurs consécutives
local finalCalled = false
ed:subscribe("IsoEvent2", function() error("err1") end)
ed:subscribe("IsoEvent2", function() error("err2") end)
ed:subscribe("IsoEvent2", function() finalCalled = true end)

local ok2 = pcall(function() ed:publish("IsoEvent2", {}) end)
ctld_test.assert(ok2,          "publish avec deux erreurs ne crash pas")
ctld_test.assert(finalCalled,  "dernier callback appelé malgré deux erreurs préalables")

ctld_test.finish()
