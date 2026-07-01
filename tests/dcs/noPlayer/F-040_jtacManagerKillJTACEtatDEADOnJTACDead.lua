---@diagnostic disable
-- ============================================================
-- F-40 : CTLDJTACManager.killJTAC → état DEAD + OnJTACDead
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

ctld.notifyCoalition = ctld.notifyCoalition or function() end

ctld_test.start("F-40", "killJTAC → état DEAD + OnJTACDead + laser libéré")

CTLDJTACManager._instance = nil
EventDispatcher._instance = nil

local dispatcher = EventDispatcher.getInstance()
local mgr = CTLDJTACManager.get()

-- Manually assign laser code so we can verify it's freed
local assignedCode = 1500
-- Remove it from pool first
for i, c in ipairs(mgr._laserPool) do
    if c == assignedCode then table.remove(mgr._laserPool, i) break end
end
local poolBefore = #mgr._laserPool

-- Inject a lasing JTAC
local jtac = CTLDJTAC:new({
    groupName    = "JTAC_Kill",
    laserCode    = assignedCode,
    isFlying     = false,
    isInfantry   = true,
    coalitionId  = coalition.side.BLUE,
    smokeEnabled = false,
    lockMode     = "all",
})
local spot = { setPoint=function()end, destroy=function()end }
local target = { unitName="BMP-2", unitType="BMP-2", unitId=77, position={x=0,y=0,z=0} }
jtac:startLase(target, spot, spot)
mgr.jtacs["JTAC_Kill"] = jtac

-- Subscribe to OnJTACDead
local received = nil
dispatcher:subscribe("OnJTACDead", function(payload)
    received = payload
end)

local killer = { unitName = "F-16C", playerName = "Viper" }
mgr:killJTAC("JTAC_Kill", killer)

-- State
ctld_test.assertEqual(jtac.state, CTLDJTAC.STATE.DEAD, "état == DEAD après killJTAC")
ctld_test.assertNil(jtac.currentTarget, "currentTarget nil après kill")

-- Event
ctld_test.assertNotNil(received, "OnJTACDead reçu")
ctld_test.assertEqual(received.jtac.groupName, "JTAC_Kill",   "payload.jtac.groupName correct")
ctld_test.assertEqual(received.jtac.laserCode, assignedCode,  "payload.jtac.laserCode correct")
ctld_test.assertEqual(received.killer.playerName, "Viper",    "payload.killer.playerName correct")
ctld_test.assertNotNil(received.lastTarget,                   "payload.lastTarget présent (was lasing)")
ctld_test.assertNotNil(received.timestamp,                    "payload.timestamp présent")

-- JTAC removed from registry
ctld_test.assertNil(mgr:getJTACByName("JTAC_Kill"), "JTAC retiré du registry après kill")

-- Laser code freed → pool +1
ctld_test.assertEqual(#mgr._laserPool, poolBefore + 1, "laser code libéré (pool +1)")

-- Guard: killJTAC on unknown group → no event
local received2 = nil
dispatcher:subscribe("OnJTACDead", function(p) received2 = p end)
mgr:killJTAC("JTAC_Unknown", nil)
ctld_test.assertNil(received2, "killJTAC(inconnu) → pas d'event")

ctld_test.finish()
