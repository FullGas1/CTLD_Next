---@diagnostic disable
-- ============================================================
-- F-28 : CTLDCrateManager.loadCrate → OnCrateLoaded
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("F-28", "loadCrate → OnCrateLoaded")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local dispatcher = EventDispatcher.getInstance()
local mgr = CTLDCrateManager.getInstance()

local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local transport = ctld_test.getTransport()

-- Inject a crate
local crate = CTLDCrate:new({ crateName="load_test", descriptor=desc,
    spawnMethod="crate_spawn", position={x=0,y=0,z=0}, coalition=coalition.side.BLUE })
mgr.crates["load_test"] = crate

-- Subscribe to OnCrateLoaded
local received = nil
dispatcher:subscribe("OnCrateLoaded", function(payload)
    received = payload
end)

-- loadCrate
mgr:loadCrate("load_test", transport)

-- State
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.LOADED, "crate état == LOADED")
ctld_test.assert(crate:isLoaded(), "crate:isLoaded() == true")
ctld_test.assert(not crate:isOnGround(), "crate pas au sol")

-- Event payload
ctld_test.assertNotNil(received, "OnCrateLoaded reçu")
ctld_test.assertEqual(received.crateName,       "load_test",         "payload.crateName correct")
ctld_test.assertEqual(received.carrierUnitName, transport:getName(), "payload.carrierUnitName correct")
ctld_test.assertEqual(received.coalition,       coalition.side.BLUE, "payload.coalition correct")
ctld_test.assertEqual(received.descriptor.unit, "M92_Ammo_Pallet",   "payload.descriptor.unit correct")
ctld_test.assertNotNil(received.timestamp,      "payload.timestamp présent")

-- Guard: loadCrate on unknown crate is silent
local received2 = nil
dispatcher:subscribe("OnCrateLoaded", function(p) received2 = p end)
mgr:loadCrate("inexistante", transport)
ctld_test.assertNil(received2, "loadCrate(inconnu) → pas d'event")

-- Guard: loadCrate on already-loaded crate is silent
local received3 = nil
dispatcher:subscribe("OnCrateLoaded", function(p) received3 = p end)
mgr:loadCrate("load_test", transport)
ctld_test.assertNil(received3, "loadCrate(déjà LOADED) → pas d'event")

ctld_test.finish()
