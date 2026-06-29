---@diagnostic disable
-- ============================================================
-- F-32 : CTLDCrateManager.dropCrate > maxDropHeight → OnCrateDestroyed
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("F-32", "dropCrate > maxDropHeight → OnCrateDestroyed")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

CTLDConfig.get().settings["maxDropHeight"] = 7.5

local dispatcher = EventDispatcher.getInstance()
local mgr        = CTLDCrateManager.getInstance()
local transport  = ctld_test.getTransport()

local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local pos  = { x = 0, y = 0, z = 0 }

-- Inject and load
local crate = CTLDCrate:new({ crateName="drop_impact", descriptor=desc,
    spawnMethod="crate_spawn", position=pos, coalition=coalition.side.BLUE })
mgr.crates["drop_impact"] = crate
mgr:loadCrate("drop_impact", transport)
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.LOADED, "crate LOADED avant drop")

-- Subscribe
local receivedDestroyed = nil
local receivedUnloaded  = nil
dispatcher:subscribe("OnCrateDestroyed", function(p) receivedDestroyed = p end)
dispatcher:subscribe("OnCrateUnloaded",  function(p) receivedUnloaded  = p end)

-- High drop (50 m > 7.5 m) → destroyed
mgr:dropCrate("drop_impact", 50)

-- Events
ctld_test.assertNotNil(receivedDestroyed, "OnCrateDestroyed reçu")
ctld_test.assertNil(receivedUnloaded,     "OnCrateUnloaded NON reçu")
ctld_test.assertEqual(receivedDestroyed.reason,    "drop_impact",   "payload.reason == drop_impact")
ctld_test.assertEqual(receivedDestroyed.crateName, "drop_impact",   "payload.crateName correct")
ctld_test.assertEqual(receivedDestroyed.coalition, coalition.side.BLUE, "payload.coalition correct")
ctld_test.assertNotNil(receivedDestroyed.timestamp, "payload.timestamp présent")

-- Crate removed from registry after impact
ctld_test.assertNil(mgr:getCrateByName("drop_impact"), "crate retirée du registry après drop_impact")

ctld_test.finish()
