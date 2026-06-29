---@diagnostic disable
-- ============================================================
-- F-121 — GAP-1 : findLoadedVehicles + unloadVehicle menu_ctld
-- Witchcraft in-DCS test (UH-1H BLUE player required)
-- ============================================================

local pass, fail = 0, 0
local function assert_eq(label, a, b)
    if a == b then
        ctld.utils.log("INFO", "[F-121 PASS] " .. label); pass = pass + 1
    else
        ctld.utils.log("INFO", string.format("[F-121 FAIL] %s  expected=%s  got=%s", label, tostring(b), tostring(a)))
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
    ctld.utils.log("INFO", "[F-121 SKIP] No active player unit found"); return
end

local _cfg     = CTLDConfig.get()
local _origVTE = _cfg.settings["vehicleTransportEnabled"]
_cfg.settings["vehicleTransportEnabled"] = { "UH-1H", "Mi-8", "Hercules", "76MD", "C-130J-30" }

local spawner = CTLDVehicleSpawner.getInstance()
local tName   = transport:getName()

-- ── Inject LOADED vehicle on this transport ──────────────────────────────────
local loadedVeh = CTLDVehicle:new({
    id = "f121_veh",
    vehicleType = "M1045 HMMWV TOW",
    unit        = nil,
    spawnData   = { groupName = "f121_veh", unitName = "f121_veh",
                    vehicleType = "M1045 HMMWV TOW", countryId = 2, coalitionId = 2 },
})
loadedVeh:setState(CTLDVehicle.STATE.LOADED)
loadedVeh.loadMethod        = "menu_ctld"
loadedVeh.loadTransportName = tName
spawner._vehicles["f121_veh"] = loadedVeh

-- ── U-05 findLoadedVehicles: returns vehicle on this transport ────────────────
local loaded = spawner:findLoadedVehicles(transport)
assert_eq("U-05 LOADED found",      #loaded, 1)
assert_eq("U-05 vehicleType ok",    loaded[1].vehicleType, "M1045 HMMWV TOW")

-- ── U-06 findLoadedVehicles: vehicle on OTHER transport not returned ──────────
local otherVeh = CTLDVehicle:new({
    id = "f121_other", vehicleType = "HMMWV", unit = nil,
    spawnData = { groupName = "f121_other", unitName = "f121_other",
                  vehicleType = "HMMWV", countryId = 2, coalitionId = 2 },
})
otherVeh:setState(CTLDVehicle.STATE.LOADED)
otherVeh.loadTransportName = "some_other_aircraft"
spawner._vehicles["f121_other"] = otherVeh
loaded = spawner:findLoadedVehicles(transport)
assert_eq("U-06 other-transport excluded", #loaded, 1)

-- ── F-02 unloadVehicle menu_ctld: state → WAITING (re-loadable) ─────────────
local _origDynAdd = ctld.utils.dynAdd
local _dynAddCalled = false
ctld.utils.dynAdd = function(_, data) _dynAddCalled = true; return { name = data.name } end

local _origGetByName = Group.getByName
Group.getByName = function(name)
    if name == "f121_veh" then
        return { getUnit = function(_)
            return { getName = function() return "f121_veh" end,
                     isExist = function() return true end } end }
    end
    return _origGetByName(name)
end

spawner:unloadVehicle(loadedVeh, transport, tName, "menu_ctld")
assert_eq("F-02 state WAITING",   loadedVeh:getState(), CTLDVehicle.STATE.WAITING)
assert_eq("F-02 dynAdd called",   _dynAddCalled,        true)

-- ── U-07 findLoadedVehicles: empty after unload ──────────────────────────────
loaded = spawner:findLoadedVehicles(transport)
assert_eq("U-07 empty after unload", #loaded, 0)

-- Cleanup
ctld.utils.dynAdd = _origDynAdd
Group.getByName   = _origGetByName
spawner._vehicles["f121_veh"]   = nil
spawner._vehicles["f121_other"] = nil
_cfg.settings["vehicleTransportEnabled"] = _origVTE

ctld.utils.log("INFO", string.format("[F-121 RESULT] pass=%d fail=%d", pass, fail))
