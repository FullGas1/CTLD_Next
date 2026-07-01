---@diagnostic disable
-- ============================================================
-- U-39 : CTLDJTAC entity — init + transitions d'états
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

ctld_test.start("U-39", "CTLDJTAC entity — init + transitions d'états")

local data = {
    groupName    = "JTAC_Alpha",
    laserCode    = 1111,
    isFlying     = false,
    isInfantry   = true,
    coalitionId  = coalition.side.BLUE,
    smokeEnabled = true,
    smokeColor   = trigger.smokeColor.Red,
    lockMode     = "all",
}

local j = CTLDJTAC:new(data)
ctld_test.assertNotNil(j,                          "CTLDJTAC:new() retourne un objet")
ctld_test.assertEqual(j.groupName,   "JTAC_Alpha", "groupName correct")
ctld_test.assertEqual(j.laserCode,   1111,         "laserCode correct")
ctld_test.assertEqual(j.isFlying,    false,         "isFlying == false")
ctld_test.assertEqual(j.isInfantry,  true,          "isInfantry == true")
ctld_test.assertEqual(j.coalitionId, coalition.side.BLUE, "coalitionId == BLUE")
ctld_test.assertEqual(j.state,       CTLDJTAC.STATE.IDLE, "état initial == IDLE")
ctld_test.assertNil(j.currentTarget, "currentTarget == nil à l'init")
ctld_test.assertNotNil(j.radio,      "radio calculé à l'init")

-- startLase
local mockSpot = { _destroyed = false,
    setPoint = function(self, p) self._pos = p end,
    destroy  = function(self) self._destroyed = true end,
}
local target = { unitName="T-72#001", unitType="T-72B", unitId=100,
    position={x=0,y=0,z=0} }
j:startLase(target, mockSpot, mockSpot)
ctld_test.assertEqual(j.state,        CTLDJTAC.STATE.LASING, "état == LASING après startLase")
ctld_test.assertNotNil(j.currentTarget, "currentTarget set après startLase")
ctld_test.assertEqual(j.currentTarget.unitName, "T-72#001", "currentTarget.unitName correct")

-- updateLaseSpot
local newPos = { x=10, y=1, z=10 }
j:updateLaseSpot(newPos)
ctld_test.assertEqual(j.currentTarget.position, newPos, "position mise à jour par updateLaseSpot")

-- stopLase
j:stopLase(CTLDJTAC.STOP_REASON.TARGET_LOST)
ctld_test.assertEqual(j.state,       CTLDJTAC.STATE.IDLE, "état == IDLE après stopLase (depuis LASING)")
ctld_test.assertNil(j.currentTarget, "currentTarget == nil après stopLase")
ctld_test.assert(mockSpot._destroyed, "laser spot destroy() appelé")

-- startOrbit / stopOrbit
j:startOrbit(100)
ctld_test.assertEqual(j.state, CTLDJTAC.STATE.ORBITING, "état == ORBITING après startOrbit")
ctld_test.assertNotNil(j.orbitStartTime, "orbitStartTime set")
j:stopOrbit()
ctld_test.assertEqual(j.state,        CTLDJTAC.STATE.IDLE, "état == IDLE après stopOrbit")
ctld_test.assertNil(j.orbitStartTime, "orbitStartTime == nil après stopOrbit")

-- ORBITING + startLase: state remains ORBITING
j:startOrbit(200)
local spot2 = { setPoint=function()end, destroy=function()end }
j:startLase(target, spot2, spot2)
ctld_test.assertEqual(j.state, CTLDJTAC.STATE.ORBITING, "startLase pendant ORBITING → reste ORBITING")

-- setInTransit
local j2 = CTLDJTAC:new(data)
j2:startLase(target, spot2, spot2)
j2:setInTransit()
ctld_test.assertEqual(j2.state, CTLDJTAC.STATE.IN_TRANSIT, "état == IN_TRANSIT après setInTransit")
ctld_test.assertNil(j2.currentTarget, "currentTarget nil après setInTransit")

-- kill
local j3 = CTLDJTAC:new(data)
j3:startLase(target, spot2, spot2)
j3:kill()
ctld_test.assertEqual(j3.state, CTLDJTAC.STATE.DEAD, "état == DEAD après kill")
ctld_test.assertNil(j3.currentTarget, "currentTarget nil après kill")

ctld_test.finish()
