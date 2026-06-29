---@diagnostic disable
-- ============================================================
-- F-122 — GAP-1 : JTAC lifecycle on loadVehicle / unloadVehicle menu_ctld
-- setJTACInTransit called on load, resumeJTAC called on unload
-- Witchcraft in-DCS test (UH-1H BLUE player required)
-- ============================================================

local pass, fail = 0, 0
local function assert_eq(label, a, b)
    if a == b then
        ctld.utils.log("INFO", "[F-122 PASS] " .. label); pass = pass + 1
    else
        ctld.utils.log("INFO", string.format("[F-122 FAIL] %s  expected=%s  got=%s", label, tostring(b), tostring(a)))
        fail = fail + 1
    end
end

local function getTransport()
    local pm = CTLDPlayerManager.getInstance()
    for unitName in pairs(pm._players) do
        local u = Unit.getByName(unitName)
        if u and u:isExist() then return u end
    end
    return nil
end

local transport = getTransport()
if not transport then
    ctld.utils.log("INFO", "[F-122 SKIP] No active player unit found"); return
end

local _cfg     = CTLDConfig.get()
local _origVTE = _cfg.settings["vehicleTransportEnabled"]
_cfg.settings["vehicleTransportEnabled"] = { "UH-1H", "Mi-8", "Hercules", "76MD", "C-130J-30" }

local spawner = CTLDVehicleSpawner.getInstance()
local tPos    = transport:getPoint()

-- Mock CTLDJTACManager to capture calls
local _jtacMgr        = CTLDJTACManager.get()
local _transitCalls   = {}
local _resumeCalls    = {}
local _origSetTransit = _jtacMgr.setJTACInTransit
local _origResume     = _jtacMgr.resumeJTAC
_jtacMgr.setJTACInTransit = function(_, gName, _) table.insert(_transitCalls, gName) end
_jtacMgr.resumeJTAC       = function(_, gName)    table.insert(_resumeCalls,  gName) end

-- Inject WAITING JTAC vehicle
local fakeUnit = {
    isExist  = function() return true end,
    getName  = function() return "f122_jtac_unit" end,
    destroy  = function() end,
    getPoint = function() return { x = tPos.x + 5, y = tPos.y, z = tPos.z + 5 } end,
}
local jtacVeh = CTLDVehicle:new({
    id = "f122_jtac", vehicleType = "Soldier M249", unit = fakeUnit,
    spawnData = { groupName = "F122_JTAC_GROUP", unitName = "f122_jtac_unit",
                  vehicleType = "Soldier M249", countryId = 2, coalitionId = 2 },
})
spawner._vehicles["f122_jtac"]           = jtacVeh
spawner._unitToVehicle["f122_jtac_unit"] = "f122_jtac"

-- ── F-03 loadVehicle: setJTACInTransit called ────────────────────────────────
spawner:loadVehicle(jtacVeh, transport, transport:getName(), "menu_ctld")
assert_eq("F-03 setJTACInTransit called once", #_transitCalls, 1)
assert_eq("F-03 correct group name",           _transitCalls[1], "F122_JTAC_GROUP")
assert_eq("F-03 state LOADED",                 jtacVeh:getState(), CTLDVehicle.STATE.LOADED)

-- ── F-04 unloadVehicle: resumeJTAC called ────────────────────────────────────
local _origDynAdd    = ctld.utils.dynAdd
local _origGetByName = Group.getByName
ctld.utils.dynAdd = function(_, data) return { name = data.name } end
Group.getByName   = function(name)
    if name == "F122_JTAC_GROUP" then
        return { getUnit = function(_)
            return { getName = function() return "f122_jtac_unit" end,
                     isExist = function() return true end } end }
    end
    return _origGetByName(name)
end

spawner:unloadVehicle(jtacVeh, transport, transport:getName(), "menu_ctld")
assert_eq("F-04 resumeJTAC called once", #_resumeCalls, 1)
assert_eq("F-04 correct group name",     _resumeCalls[1], "F122_JTAC_GROUP")
assert_eq("F-04 state WAITING",          jtacVeh:getState(), CTLDVehicle.STATE.WAITING)

-- Cleanup
_jtacMgr.setJTACInTransit        = _origSetTransit
_jtacMgr.resumeJTAC              = _origResume
ctld.utils.dynAdd                = _origDynAdd
Group.getByName                  = _origGetByName
spawner._vehicles["f122_jtac"]   = nil
spawner._unitToVehicle["f122_jtac_unit"] = nil
_cfg.settings["vehicleTransportEnabled"] = _origVTE

ctld.utils.log("INFO", string.format("[F-122 RESULT] pass=%d fail=%d", pass, fail))
