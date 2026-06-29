---@diagnostic disable
-- ============================================================
-- F-29 : CTLDCrateManager.unloadCrate → OnCrateUnloaded
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("F-29", "unloadCrate → OnCrateUnloaded")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local dispatcher = EventDispatcher.getInstance()
local mgr = CTLDCrateManager.getInstance()

local desc      = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local transport = ctld_test.getTransport()
local dropPos   = { x = 500, y = 0, z = 300 }

-- Inject a crate and load it
local crate = CTLDCrate:new({ crateName="unload_test", descriptor=desc,
    spawnMethod="crate_spawn", position={x=0,y=0,z=0}, coalition=coalition.side.BLUE })
mgr.crates["unload_test"] = crate
mgr:loadCrate("unload_test", transport)
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.LOADED, "crate LOADED avant unload")

-- Subscribe to OnCrateUnloaded
local received = nil
dispatcher:subscribe("OnCrateUnloaded", function(payload)
    received = payload
end)

-- Unload
mgr:unloadCrate("unload_test", dropPos, "menu_ctld")

-- State
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.LANDED,  "crate état == LANDED après unload")
ctld_test.assert(crate:isOnGround(),  "crate au sol après unload")
ctld_test.assert(not crate:isLoaded(), "crate pas chargée après unload")

-- Event payload
ctld_test.assertNotNil(received,                    "OnCrateUnloaded reçu")
ctld_test.assertEqual(received.crateName, "unload_test", "payload.crateName correct")
ctld_test.assertEqual(received.method,    "menu_ctld",   "payload.method == menu_ctld")
ctld_test.assertEqual(received.coalition, coalition.side.BLUE, "payload.coalition correct")
ctld_test.assertEqual(received.position,  dropPos,       "payload.position correct")
ctld_test.assertNotNil(received.timestamp,              "payload.timestamp présent")

-- Guard: unloadCrate on unknown crate is silent
local received2 = nil
dispatcher:subscribe("OnCrateUnloaded", function(p) received2 = p end)
mgr:unloadCrate("inexistante", dropPos, "menu_ctld")
ctld_test.assertNil(received2, "unloadCrate(inconnu) → pas d'event")

ctld_test.finish()
