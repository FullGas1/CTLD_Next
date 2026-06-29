---@diagnostic disable
-- ============================================================
-- U-05 : CTLDDCSEventBridge — singleton + register + route event
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Vérifier le singleton, l'enregistrement d'un handler,
--           et le dispatch vers la bonne méthode via onEvent().
-- Note    : world.addEventHandler est appelé par init() — en mission
--           DCS active (Witchcraft) l'appel est réel et légitime.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("U-05", "CTLDDCSEventBridge — singleton + register + route event")

-- Reset singletons
CTLDDCSEventBridge._instance = nil

local bridge1 = CTLDDCSEventBridge.getInstance()
local bridge2 = CTLDDCSEventBridge.getInstance()

ctld_test.assertNotNil(bridge1, "getInstance() retourne instance non-nil")
ctld_test.assert(bridge1 == bridge2, "singleton : même référence sur deux appels")
ctld_test.assert(type(bridge1._handlers) == "table", "_handlers est une table")

-- Test register : enregistrer un handler fictif
local receivedEvent = nil
local fakeManager = {
    onTestEvent = function(self, event)
        receivedEvent = event
    end
}

local fakeEventId = 9999  -- id fictif non utilisé par DCS
bridge1:register(fakeManager, fakeEventId, "onTestEvent")

-- Vérifier que l'entrée est bien dans _handlers
ctld_test.assertNotNil(bridge1._handlers[fakeEventId], "handler table créée pour fakeEventId")
ctld_test.assertEqual(#bridge1._handlers[fakeEventId], 1, "exactement 1 handler enregistré")

-- Test onEvent : dispatch manuel
local fakeEvent = { id = fakeEventId, initiator = nil }
bridge1:onEvent(fakeEvent)

ctld_test.assertNotNil(receivedEvent, "handler appelé par onEvent")
ctld_test.assertEqual(receivedEvent.id, fakeEventId, "event.id transmis correctement")

-- Test : event id inconnu → pas d'erreur
local ok = pcall(function() bridge1:onEvent({ id = 88888 }) end)
ctld_test.assert(ok, "onEvent avec id inconnu ne crash pas")

-- Test : handler qui throw → bridge isole l'erreur
local crashManager = {
    onCrash = function(self, event) error("handler crash test") end
}
bridge1:register(crashManager, fakeEventId, "onCrash")
local ok2 = pcall(function() bridge1:onEvent(fakeEvent) end)
ctld_test.assert(ok2, "onEvent isole l'erreur d'un handler défaillant")

ctld_test.finish()
