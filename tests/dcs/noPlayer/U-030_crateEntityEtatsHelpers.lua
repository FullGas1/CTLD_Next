---@diagnostic disable
-- ============================================================
-- U-30 : CTLDCrate entity — états + helpers
-- Module  : R1 (src/CTLD_crate.lua)
-- Objectif: Vérifier transitions d'état SPAWNED→LOADED→LANDED→UNPACKED
--   + isOnGround / isLoaded / destroy
-- Précondition : aucun transport requis.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("U-30", "CTLDCrate entity — états + helpers")

local pos = { x = 0, y = 0, z = 0 }
local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }

local crate = CTLDCrate:new({
    crateName   = "test_crate_U30",
    descriptor  = desc,
    spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
    position    = pos,
    coalition   = coalition.side.BLUE,
})

-- État initial
ctld_test.assertNotNil(crate, "CTLDCrate:new() retourne un objet")
ctld_test.assertEqual(crate.state,      CTLDCrate.STATE.SPAWNED, "état initial == SPAWNED")
ctld_test.assertEqual(crate.hasMoved,   false,                   "hasMoved == false à l'init")
ctld_test.assertEqual(crate.isParachuting, false,                "isParachuting == false à l'init")
ctld_test.assert(crate:isOnGround(),    "isOnGround() == true à l'init (SPAWNED)")
ctld_test.assert(not crate:isLoaded(), "isLoaded() == false à l'init")

-- LOADED
local mockTransport = { _name = "heli_test" }
function mockTransport:getName() return self._name end
crate:load(mockTransport)
ctld_test.assertEqual(crate.state,   CTLDCrate.STATE.LOADED, "état == LOADED après load()")
ctld_test.assertEqual(crate.hasMoved, true,                  "hasMoved == true après load()")
ctld_test.assert(crate:isLoaded(),   "isLoaded() == true après load()")
ctld_test.assert(not crate:isOnGround(), "isOnGround() == false quand LOADED")

-- LANDED (unload)
local newPos = { x = 100, y = 0, z = 100 }
crate:unload(newPos)
ctld_test.assertEqual(crate.state,   CTLDCrate.STATE.LANDED, "état == LANDED après unload()")
ctld_test.assert(crate:isOnGround(), "isOnGround() == true quand LANDED")
ctld_test.assert(not crate:isLoaded(), "isLoaded() == false quand LANDED")
ctld_test.assertNil(crate.loadedBy,  "loadedBy == nil après unload()")

-- FALLING (drop)
crate:load(mockTransport)
crate:drop(newPos)
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.FALLING, "état == FALLING après drop()")
ctld_test.assert(not crate:isOnGround(), "isOnGround() == false quand FALLING")

-- land (retour au sol après chute)
crate:land(newPos)
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.LANDED, "état == LANDED après land()")

-- UNPACKED
crate:unpack()
ctld_test.assertEqual(crate.state, CTLDCrate.STATE.UNPACKED, "état == UNPACKED après unpack()")
ctld_test.assert(not crate:isOnGround(), "isOnGround() == false quand UNPACKED")

-- startParachute stub
local crate2 = CTLDCrate:new({ crateName="c2", descriptor=desc, spawnMethod="crate_spawn",
    position=pos, coalition=coalition.side.BLUE })
crate2:startParachute(500)
ctld_test.assertEqual(crate2.state, CTLDCrate.STATE.FALLING, "startParachute → FALLING")
ctld_test.assertEqual(crate2.isParachuting, true,            "isParachuting == true")

-- destroy sans dcsStatic ne crash pas
local okDestroy = pcall(function() crate:destroy() end)
ctld_test.assert(okDestroy, "destroy() sans dcsStatic ne crash pas")

ctld_test.finish()
