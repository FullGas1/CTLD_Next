---@diagnostic disable
-- ============================================================
-- F-38 : CTLDJTACManager.setJTACInTransit → état + OnJTACInTransit
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

ctld.notifyCoalition = ctld.notifyCoalition or function() end

ctld_test.start("F-38", "setJTACInTransit → état + OnJTACInTransit")

CTLDJTACManager._instance = nil
EventDispatcher._instance = nil

local dispatcher = EventDispatcher.getInstance()
local mgr = CTLDJTACManager.get()

-- Inject a JTAC directly into registry (no need to spawn through DCS)
local jtac = CTLDJTAC:new({
    groupName    = "JTAC_Transit",
    laserCode    = 1300,
    isFlying     = false,
    isInfantry   = true,
    coalitionId  = coalition.side.BLUE,
    smokeEnabled = false,
    lockMode     = "all",
})
mgr.jtacs["JTAC_Transit"] = jtac

-- Set a current target (will be cleared by setInTransit)
local spot = { setPoint=function()end, destroy=function()end }
jtac:startLase({ unitName="T-72", unitType="T-72B", unitId=1, position={x=0,y=0,z=0} },
    spot, spot)
ctld_test.assertEqual(jtac.state, CTLDJTAC.STATE.LASING, "JTAC en LASING avant transit")

-- Subscribe to OnJTACInTransit
local received = nil
dispatcher:subscribe("OnJTACInTransit", function(payload)
    received = payload
end)

local transport = { unitName = "uh1-1", playerName = "Pilot" }
mgr:setJTACInTransit("JTAC_Transit", transport)

-- State
ctld_test.assertEqual(jtac.state, CTLDJTAC.STATE.IN_TRANSIT, "état == IN_TRANSIT après setJTACInTransit")
ctld_test.assertNil(jtac.currentTarget, "currentTarget nil (lase stoppé en transit)")

-- Event
ctld_test.assertNotNil(received, "OnJTACInTransit reçu")
ctld_test.assertEqual(received.jtac.groupName, "JTAC_Transit", "payload.jtac.groupName correct")
ctld_test.assertEqual(received.transport.unitName, "uh1-1",     "payload.transport.unitName correct")
ctld_test.assertNotNil(received.timestamp,                      "payload.timestamp présent")

-- Guard: setJTACInTransit on DEAD JTAC → no event
local received2 = nil
dispatcher:subscribe("OnJTACInTransit", function(p) received2 = p end)
local jtac2 = CTLDJTAC:new({ groupName="JTAC_Dead", laserCode=1400,
    isFlying=false, isInfantry=true, coalitionId=coalition.side.BLUE,
    smokeEnabled=false, lockMode="all" })
jtac2.state = CTLDJTAC.STATE.DEAD
mgr.jtacs["JTAC_Dead"] = jtac2
mgr:setJTACInTransit("JTAC_Dead", transport)
ctld_test.assertNil(received2, "setJTACInTransit(DEAD JTAC) → pas d'event")

-- Guard: setJTACInTransit on unknown group → no event
local received3 = nil
dispatcher:subscribe("OnJTACInTransit", function(p) received3 = p end)
mgr:setJTACInTransit("JTAC_Unknown", transport)
ctld_test.assertNil(received3, "setJTACInTransit(inconnu) → pas d'event")

ctld_test.finish()
