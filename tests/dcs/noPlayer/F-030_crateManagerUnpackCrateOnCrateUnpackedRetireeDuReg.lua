---@diagnostic disable
-- ============================================================
-- F-30 : CTLDCrateManager.unpackCrate → OnCrateUnpacked + retirée du registry
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("F-30", "unpackCrate → OnCrateUnpacked + retirée du registry")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local dispatcher = EventDispatcher.getInstance()
local mgr        = CTLDCrateManager.getInstance()
local unpacker   = ctld_test.getTransport()

local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local pos  = { x = 50, y = 0, z = 100 }

-- Inject a LANDED crate (SPAWNED is also on-ground)
local crate = CTLDCrate:new({ crateName="unpack_test", descriptor=desc,
    spawnMethod="crate_spawn", position=pos, coalition=coalition.side.BLUE })
mgr.crates["unpack_test"] = crate

-- Subscribe to OnCrateUnpacked
local received = nil
dispatcher:subscribe("OnCrateUnpacked", function(payload)
    received = payload
end)

-- Unpack
mgr:unpackCrate("unpack_test", unpacker)

-- State: UNPACKED
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.UNPACKED, "crate état == UNPACKED")

-- Event payload
ctld_test.assertNotNil(received,                         "OnCrateUnpacked reçu")
ctld_test.assertEqual(received.crateName, "unpack_test", "payload.crateName correct")
ctld_test.assertEqual(received.coalition, coalition.side.BLUE, "payload.coalition correct")
ctld_test.assertEqual(received.descriptor.unit, "M92_Ammo_Pallet", "payload.descriptor.unit correct")
ctld_test.assertEqual(received.carrierUnitName, unpacker:getName(), "payload.carrierUnitName correct")
ctld_test.assertNotNil(received.timestamp,               "payload.timestamp présent")

-- Crate removed from registry
ctld_test.assertNil(mgr:getCrateByName("unpack_test"), "crate retirée du registry après unpack")

-- Guard: unpackCrate on LOADED crate (not on ground) is silent
local crate2 = CTLDCrate:new({ crateName="unpack_loaded", descriptor=desc,
    spawnMethod="crate_spawn", position=pos, coalition=coalition.side.BLUE })
crate2:load(unpacker)   -- LOADED
mgr.crates["unpack_loaded"] = crate2

local received2 = nil
dispatcher:subscribe("OnCrateUnpacked", function(p) received2 = p end)
mgr:unpackCrate("unpack_loaded", unpacker)
ctld_test.assertNil(received2, "unpackCrate(LOADED) → pas d'event (pas au sol)")
ctld_test.assertNotNil(mgr:getCrateByName("unpack_loaded"), "crate LOADED reste dans le registry")

ctld_test.finish()
