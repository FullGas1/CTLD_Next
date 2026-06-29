---@diagnostic disable
-- ============================================================
-- F-37 : CTLDJTACManager.spawnJTAC + registerMMJTAC → OnJTACSpawned
-- Module  : R3 (src/CTLD_jtac.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_jtac.lua")

-- Stub ctld.notifyCoalition (not defined in src modules)
ctld.notifyCoalition = ctld.notifyCoalition or function() end

ctld_test.start("F-37", "spawnJTAC + registerMMJTAC → OnJTACSpawned")

CTLDJTACManager._instance = nil
EventDispatcher._instance = nil

local dispatcher = EventDispatcher.getInstance()
local mgr = CTLDJTACManager.get()

-- Guard: spawnJTAC on unknown group → nil
local r0 = mgr:spawnJTAC("NonExistentGroup", nil, nil)
ctld_test.assertNil(r0, "spawnJTAC(groupe inconnu) → nil")

-- Use a mock ground-infantry group to avoid isFlying branch (ctrl:getTask() unsupported)
local mockUnit = {
    _desc = { attributes = { Infantry = true } },
    getName      = function(self) return "MockJTAC_unit1" end,
    getID        = function(self) return 9901 end,
    getTypeName  = function(self) return "Soldier M4 GRG" end,
    getPoint     = function(self) return { x=0, y=0, z=0 } end,
    getDesc      = function(self) return self._desc end,
}
local mockGroup = {
    _name  = "MockJTAC_grp",
    _coa   = coalition.side.BLUE,
    getName       = function(self) return self._name end,
    getID         = function(self) return 9900 end,
    getCoalition  = function(self) return self._coa end,
    getUnits      = function(self) return { mockUnit } end,
    getUnit       = function(self, i) return mockUnit end,
    getController = function(self) return nil end,  -- nil → skips initialRoute
    isExist       = function(self) return true end,
}
local groupName = mockGroup._name

-- Override Group.getByName for mock group
local origGetByName = Group.getByName
Group.getByName = function(name)
    if name == groupName then return mockGroup end
    return origGetByName(name)
end

-- Subscribe to OnJTACSpawned
local received = nil
dispatcher:subscribe("OnJTACSpawned", function(payload)
    received = payload
end)

-- spawnJTAC with explicit config
local cfg = { laserCode = 1200, smokeEnabled = false, lockMode = "vehicle" }
local jtac = mgr:spawnJTAC(groupName, cfg, nil)

ctld_test.assertNotNil(jtac, "spawnJTAC retourne un CTLDJTAC")
ctld_test.assertEqual(jtac.laserCode, 1200,           "laserCode == 1200")
ctld_test.assertEqual(jtac.lockMode,  "vehicle",      "lockMode == vehicle")
ctld_test.assertEqual(jtac.state,     CTLDJTAC.STATE.IDLE, "état initial == IDLE")

-- Event received
ctld_test.assertNotNil(received, "OnJTACSpawned reçu")
ctld_test.assertEqual(received.laserCode,  1200,        "payload.laserCode == 1200")
ctld_test.assertEqual(received.lockMode,   "vehicle",   "payload.lockMode correct")
ctld_test.assertNotNil(received.radio,     "payload.radio présent")
ctld_test.assertNotNil(received.timestamp, "payload.timestamp présent")

-- Stored in jtacs registry
ctld_test.assertEqual(mgr:getJTACByName(groupName), jtac, "getJTACByName retourne le JTAC")

-- markPendingJTAC + _isPendingJTAC + _clearPendingJTAC
mgr:markPendingJTAC("PendingGroup")
ctld_test.assert(mgr:_isPendingJTAC("PendingGroup"), "markPendingJTAC → _isPendingJTAC == true")
mgr:_clearPendingJTAC("PendingGroup")
ctld_test.assert(not mgr:_isPendingJTAC("PendingGroup"), "_clearPendingJTAC → false")

-- Restore Group.getByName
Group.getByName = origGetByName

ctld_test.finish()
