---@diagnostic disable
-- ============================================================
-- F-123 — _dispatchPostSpawn enregistre les véhicules GROUND dans CTLDVehicleSpawner
-- Vérifie que après unpack d'une caisse standard (non-JTAC), le véhicule
-- apparaît dans findLoadableVehicles du transport.
-- Witchcraft in-DCS (UH-1H BLUE player required)
-- ============================================================

local pass, fail = 0, 0
local function assert_eq(label, a, b)
    if a == b then
        ctld.utils.log("INFO", "[F-123 PASS] " .. label); pass = pass + 1
    else
        ctld.utils.log("INFO", string.format("[F-123 FAIL] %s  expected=%s  got=%s",
            label, tostring(b), tostring(a)))
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
    ctld.utils.log("INFO", "[F-123 SKIP] No active player unit found"); return
end

local spawner = CTLDVehicleSpawner.getInstance()
local mgr     = CTLDCrateManager.getInstance()
local tPos    = transport:getPoint()

-- Count vehicles registered before test
local countBefore = 0
for _ in pairs(spawner._vehicles) do countBefore = countBefore + 1 end

-- Build a fake non-JTAC ground descriptor
local fakeDesc = { unit = "M1045 HMMWV TOW", desc = "HMMWV TOW", spawnAs = "GROUND",
                   isJTAC = false, cratesRequired = 1 }

-- Mock spawnFromDescriptor + Group.getByName so no real DCS unit is needed
local _origSpawn     = ctld.utils.spawnFromDescriptor
local _origGetByName = Group.getByName
local _spawnedGroup  = "CTLD_UNP_F123"
ctld.utils.spawnFromDescriptor = function(_, _, _) return true, nil end
Group.getByName = function(name)
    if name == _spawnedGroup then
        return { getUnit = function(_)
            return { getName       = function() return _spawnedGroup .. "_u1" end,
                     isExist       = function() return true end,
                     getCoalition  = function() return coalition.side.BLUE end,
                     getCountry    = function() return country.id.USA end,
                     getPoint      = function() return { x = tPos.x + 20, y = tPos.y, z = tPos.z + 20 } end } end }
    end
    return _origGetByName(name)
end

-- Patch getNextUniqId to return predictable IDs for gname
local _origUniqId = ctld.utils.getNextUniqId
local _callCount  = 0
ctld.utils.getNextUniqId = function()
    _callCount = _callCount + 1
    -- _spawnUnpacked calls getNextUniqId twice: gid then uid → gname = CTLD_UNP_<uid>
    if _callCount == 1 then return 9900 end   -- gid
    if _callCount == 2 then return 123  end   -- uid → CTLD_UNP_123
    return _origUniqId()
end
_spawnedGroup = "CTLD_UNP_123"

-- ── F-05 _dispatchPostSpawn: non-JTAC GROUND vehicle registered ──────────────
local spawnPos = { x = tPos.x + 20, y = tPos.y, z = tPos.z + 20 }
mgr:_spawnUnpacked(fakeDesc, spawnPos, coalition.side.BLUE, country.id.USA)

local countAfter = 0
for _ in pairs(spawner._vehicles) do countAfter = countAfter + 1 end
assert_eq("F-05 vehicle count increased", countAfter, countBefore + 1)

-- ── U-08 findLoadableVehicles: unpack'd vehicle appears in list ───────────────
local near = spawner:findLoadableVehicles(transport)
local found = false
for _, v in ipairs(near) do
    if v.vehicleType == "M1045 HMMWV TOW" then found = true end
end
assert_eq("U-08 unpacked vehicle found by findLoadableVehicles", found, true)

-- Cleanup: remove the injected vehicle
for id, v in pairs(spawner._vehicles) do
    if v.vehicleType == "M1045 HMMWV TOW" and v.spawnData
        and v.spawnData.groupName == _spawnedGroup then
        spawner._unitToVehicle[_spawnedGroup .. "_u1"] = nil
        spawner._vehicles[id] = nil
        break
    end
end
ctld.utils.spawnFromDescriptor = _origSpawn
Group.getByName                = _origGetByName
ctld.utils.getNextUniqId       = _origUniqId

ctld.utils.log("INFO", string.format("[F-123 RESULT] pass=%d fail=%d", pass, fail))
