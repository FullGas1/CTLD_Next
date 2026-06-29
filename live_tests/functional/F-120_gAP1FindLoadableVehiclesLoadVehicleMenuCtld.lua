---@diagnostic disable
-- ============================================================
-- F-120 — GAP-1 : findLoadableVehicles + loadVehicle menu_ctld
-- Witchcraft in-DCS test (UH-1H BLUE player required)
-- ============================================================

local pass, fail = 0, 0
local function assert_eq(label, a, b)
    if a == b then
        ctld.utils.log("INFO", "[F-120 PASS] " .. label); pass = pass + 1
    else
        ctld.utils.log("INFO", string.format("[F-120 FAIL] %s  expected=%s  got=%s", label, tostring(b), tostring(a)))
        fail = fail + 1
    end
end

-- Find first active BLUE transport player
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
    ctld.utils.log("INFO", "[F-120 SKIP] No active player unit found"); return
end

-- Force UH-1H to be canCarryVehicles for this test session
local _cfg     = CTLDConfig.get()
local _origVTE = _cfg.settings["vehicleTransportEnabled"]
_cfg.settings["vehicleTransportEnabled"] = { "UH-1H", "Mi-8", "Hercules", "76MD", "C-130J-30" }

local spawner = CTLDVehicleSpawner.getInstance()
local tPos    = transport:getPoint()

-- ── U-01 findLoadableVehicles: empty when no WAITING vehicles ────────────────
local near = spawner:findLoadableVehicles(transport)
assert_eq("U-01 empty before inject", #near, 0)

-- ── Inject WAITING vehicle close to transport ────────────────────────────────
local fakeUnit = {
    isExist  = function() return true end,
    getPoint = function() return { x = tPos.x + 10, y = tPos.y, z = tPos.z + 10 } end,
    getName  = function() return "f120_veh_unit" end,
    destroy  = function() end,
}
local fakeVeh = CTLDVehicle:new({
    id          = "f120_veh",
    vehicleType = "M1045 HMMWV TOW",
    unit        = fakeUnit,
    spawnData   = { groupName = "f120_veh", unitName = "f120_veh_unit",
                    vehicleType = "M1045 HMMWV TOW", countryId = 2, coalitionId = 2 },
})
spawner._vehicles["f120_veh"]          = fakeVeh
spawner._unitToVehicle["f120_veh_unit"] = "f120_veh"

-- ── U-02 findLoadableVehicles: finds WAITING vehicle in range ────────────────
near = spawner:findLoadableVehicles(transport)
assert_eq("U-02 WAITING found", #near, 1)
assert_eq("U-02 vehicleType ok", near[1].vehicleType, "M1045 HMMWV TOW")

-- ── U-03 findLoadableVehicles: vehicle out of range not returned ─────────────
local farUnit = {
    isExist  = function() return true end,
    getPoint = function() return { x = tPos.x + 9999, y = tPos.y, z = tPos.z } end,
    getName  = function() return "f120_far_unit" end,
}
local farVeh = CTLDVehicle:new({
    id = "f120_far", vehicleType = "HMMWV", unit = farUnit,
    spawnData = { groupName = "f120_far", unitName = "f120_far_unit",
                  vehicleType = "HMMWV", countryId = 2, coalitionId = 2 },
})
spawner._vehicles["f120_far"] = farVeh
near = spawner:findLoadableVehicles(transport)
assert_eq("U-03 far vehicle excluded", #near, 1)

-- ── F-01 loadVehicle menu_ctld: state → LOADED, destroy called ───────────────
local _destroyed = false
fakeVeh.unit = {
    isExist  = function() return true end,
    getName  = function() return "f120_veh_unit" end,
    destroy  = function() _destroyed = true end,
    getPoint = function() return { x = tPos.x + 10, y = tPos.y, z = tPos.z + 10 } end,
}
spawner:loadVehicle(fakeVeh, transport, transport:getName(), "menu_ctld")
assert_eq("F-01 state LOADED",          fakeVeh:getState(), CTLDVehicle.STATE.LOADED)
assert_eq("F-01 destroy called",        _destroyed,         true)
assert_eq("F-01 loadTransportName set", fakeVeh.loadTransportName, transport:getName())
assert_eq("F-01 loadMethod set",        fakeVeh.loadMethod, "menu_ctld")

-- ── U-04 findLoadableVehicles: LOADED vehicle no longer listed ───────────────
near = spawner:findLoadableVehicles(transport)
assert_eq("U-04 LOADED excluded",       #near, 0)

-- Cleanup
spawner._vehicles["f120_veh"]           = nil
spawner._vehicles["f120_far"]           = nil
spawner._unitToVehicle["f120_veh_unit"] = nil
_cfg.settings["vehicleTransportEnabled"] = _origVTE

ctld.utils.log("INFO", string.format("[F-120 RESULT] pass=%d fail=%d", pass, fail))
