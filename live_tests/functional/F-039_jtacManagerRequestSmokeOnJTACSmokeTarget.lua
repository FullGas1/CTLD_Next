---@diagnostic disable
-- ============================================================
-- F-39 : CTLDJTACManager.requestSmoke → OnJTACSmokeTarget
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

ctld.notifyCoalition = ctld.notifyCoalition or function() end

ctld_test.start("F-39", "requestSmoke → OnJTACSmokeTarget")

CTLDJTACManager._instance = nil
EventDispatcher._instance = nil

CTLDConfig.get().settings["JTAC_smokeMarginOfError"] = 0   -- no random offset for deterministic test
CTLDConfig.get().settings["JTAC_smokeOffset_y"]      = 2

local dispatcher = EventDispatcher.getInstance()
local mgr = CTLDJTACManager.get()

-- Inject a lasing JTAC
local jtac = CTLDJTAC:new({
    groupName    = "JTAC_Smoke",
    laserCode    = 1111,
    isFlying     = false,
    isInfantry   = true,
    coalitionId  = coalition.side.BLUE,
    smokeEnabled = true,
    smokeColor   = trigger.smokeColor.Red,
    lockMode     = "all",
})
local targetPos = { x=500, y=10, z=800 }
local spot = { setPoint=function()end, destroy=function()end }
jtac:startLase({ unitName="T-55", unitType="T-55", unitId=42, position=targetPos }, spot, spot)
mgr.jtacs["JTAC_Smoke"] = jtac

-- Subscribe to OnJTACSmokeTarget
local received = nil
dispatcher:subscribe("OnJTACSmokeTarget", function(payload)
    received = payload
end)

-- requestSmoke
mgr:requestSmoke("JTAC_Smoke")

ctld_test.assertNotNil(received, "OnJTACSmokeTarget reçu")
ctld_test.assertEqual(received.jtac.groupName, "JTAC_Smoke",        "payload.jtac.groupName correct")
ctld_test.assertEqual(received.target.unitName, "T-55",             "payload.target.unitName correct")
ctld_test.assertEqual(received.smokeColor, trigger.smokeColor.Red,  "payload.smokeColor correct")
ctld_test.assertNotNil(received.smokePosition,                      "payload.smokePosition présent")
-- With margin=0: smokePos.x == targetPos.x, smokePos.z == targetPos.z, .y == targetPos.y + 2
ctld_test.assertEqual(received.smokePosition.x, targetPos.x,        "smokePos.x == targetPos.x (margin=0)")
ctld_test.assertEqual(received.smokePosition.z, targetPos.z,        "smokePos.z == targetPos.z (margin=0)")
ctld_test.assertEqual(received.smokePosition.y, targetPos.y + 2,    "smokePos.y == targetPos.y + offset")
ctld_test.assertNotNil(received.timestamp,                          "payload.timestamp présent")

-- Guard: requestSmoke without active target → no event
local received2 = nil
dispatcher:subscribe("OnJTACSmokeTarget", function(p) received2 = p end)
local jtac2 = CTLDJTAC:new({ groupName="JTAC_NoTarget", laserCode=1222,
    isFlying=false, isInfantry=true, coalitionId=coalition.side.BLUE,
    smokeEnabled=true, lockMode="all" })
mgr.jtacs["JTAC_NoTarget"] = jtac2
mgr:requestSmoke("JTAC_NoTarget")
ctld_test.assertNil(received2, "requestSmoke sans target → pas d'event")

-- Guard: requestSmoke on unknown JTAC → no event
local received3 = nil
dispatcher:subscribe("OnJTACSmokeTarget", function(p) received3 = p end)
mgr:requestSmoke("JTAC_Unknown")
ctld_test.assertNil(received3, "requestSmoke(inconnu) → pas d'event")

ctld_test.finish()
