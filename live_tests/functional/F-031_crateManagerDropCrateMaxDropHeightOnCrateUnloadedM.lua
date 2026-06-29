---@diagnostic disable
-- ============================================================
-- F-31 : CTLDCrateManager.dropCrate ≤ maxDropHeight → OnCrateUnloaded method=drop
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("F-31", "dropCrate ≤ maxDropHeight → OnCrateUnloaded method=drop")

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

-- maxDropHeight default = 7.5 m — drop at 5 m → safe
CTLDConfig.get().settings["maxDropHeight"] = 7.5

local dispatcher = EventDispatcher.getInstance()
local mgr        = CTLDCrateManager.getInstance()
local transport  = ctld_test.getTransport()

local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local pos  = { x = 0, y = 0, z = 0 }

-- Inject and load
local crate = CTLDCrate:new({ crateName="drop_safe", descriptor=desc,
    spawnMethod="crate_spawn", position=pos, coalition=coalition.side.BLUE })
mgr.crates["drop_safe"] = crate
mgr:loadCrate("drop_safe", transport)
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.LOADED, "crate LOADED avant drop")

-- Subscribe to OnCrateUnloaded
local receivedUnloaded   = nil
local receivedDestroyed  = nil
dispatcher:subscribe("OnCrateUnloaded",   function(p) receivedUnloaded  = p end)
dispatcher:subscribe("OnCrateDestroyed",  function(p) receivedDestroyed = p end)

-- Safe drop (5 m ≤ 7.5 m)
mgr:dropCrate("drop_safe", 5)

-- State
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.LANDED, "crate LANDED après drop safe")
ctld_test.assert(crate:isOnGround(), "crate au sol après drop safe")

-- Events
ctld_test.assertNotNil(receivedUnloaded,  "OnCrateUnloaded reçu")
ctld_test.assertNil(receivedDestroyed,    "OnCrateDestroyed NON reçu")
ctld_test.assertEqual(receivedUnloaded.method, "drop", "payload.method == drop")
ctld_test.assertEqual(receivedUnloaded.crateName, "drop_safe", "payload.crateName correct")
ctld_test.assertNotNil(receivedUnloaded.timestamp, "payload.timestamp présent")

-- Crate still in registry after safe drop
ctld_test.assertNotNil(mgr:getCrateByName("drop_safe"), "crate toujours dans registry après drop safe")

-- Guard: dropCrate on non-loaded crate is silent
local received2 = nil
dispatcher:subscribe("OnCrateUnloaded", function(p) received2 = p end)
local crate2 = CTLDCrate:new({ crateName="drop_notloaded", descriptor=desc,
    spawnMethod="crate_spawn", position=pos, coalition=coalition.side.BLUE })
mgr.crates["drop_notloaded"] = crate2
mgr:dropCrate("drop_notloaded", 5)
ctld_test.assertNil(received2, "dropCrate(non LOADED) → pas d'event")

ctld_test.finish()
