---@diagnostic disable
-- =============================================================================
-- AUTO — Feature Q: Vehicle whole-unit air transport
-- =============================================================================
-- F-Q-1 : findLoadableVehicles — UH-1H (no canTransportWholeVehicle) → returns {}
-- F-Q-2 : findLoadableVehicles — C-130 BLUE + HMMWV BLUE WAITING in range → returned
-- F-Q-3 : findLoadableVehicles — C-130 BLUE + BRDM-2 RED WAITING in range → excluded (coalition)
-- F-Q-4 : findLoadableVehicles — C-130 BLUE + unknown type → excluded (type)
-- F-Q-5 : refreshRequestEquipmentSection C-130 + loadable singleCrate → spawnAsVehicle=true
-- F-Q-6 : refreshRequestEquipmentSection UH-1H + same singleCrate → spawnAsVehicle=false
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FQ] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_FQ_RUNNING then
    trigger.action.outText("[FQ] already running.", 10)
    return Witchcraft
end
_SCN_FQ_RUNNING = true

do  -- isolation scope
trigger.action.outText("[FQ] START — Vehicle whole-unit transport", 8)

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local pass = 0
local fail = 0

local function check(label, actual, expected)
    if actual == expected then
        ctld.utils.log("INFO", "[PASS] %s = %s", label, tostring(actual))
        pass = pass + 1
    else
        ctld.utils.log("ERROR", "[FAIL] %s : expected=%s actual=%s", label, tostring(expected), tostring(actual))
        fail = fail + 1
    end
end
local function checkTrue(label, cond)  check(label, cond == true, true) end
local function checkFalse(label, cond) check(label, cond == false or cond == nil, true) end

-- ── Save config ───────────────────────────────────────────────────────────────
local _savedCaps = cfg.settings["capabilitiesByType"]
local _savedDist = cfg.settings["maximumDistancePackableUnitsSearch"]

-- ── Setup capabilitiesByType mock ─────────────────────────────────────────────
cfg.settings["capabilitiesByType"] = {
    ["C-130"] = {
        cratesEnabled            = true,
        canTransportWholeVehicle = true,
        loadableVehiclesRED      = { "BRDM-2" },
        loadableVehiclesBLUE     = { "M1045 HMMWV TOW" },
    },
    ["UH-1H"] = {
        cratesEnabled            = true,
        canTransportWholeVehicle = nil,
    },
}
cfg.settings["maximumDistancePackableUnitsSearch"] = 1000

-- ============================================================
-- findLoadableVehicles tests (F-Q-1 to F-Q-4)
-- ============================================================

local vs = CTLDVehicleSpawner.getInstance()

-- Save vehicles table
local _savedVehicles     = vs._vehicles
local _savedUnitToVehicle = vs._unitToVehicle

-- Helper: create a mock unit at the given distance from transport
local function makeMockUnit(x, z)
    return {
        isExist  = function() return true end,
        getPoint = function() return { x = x, y = 0, z = z } end,
    }
end

-- Helper: create a mock CTLDVehicle
local function makeMockVehicle(vehicleType, coalitionId, unit)
    local v = {
        vehicleType = vehicleType,
        state       = CTLDVehicle.STATE.WAITING,
        spawnData   = { coalitionId = coalitionId, groupName = nil },
        unit        = unit,
    }
    function v:getState() return self.state end
    return v
end

-- Mock transport (pos 0,0)
local function makeMockTransport(typeName, coalition)
    return {
        getTypeName  = function() return typeName end,
        getCoalition = function() return coalition end,
        getPoint     = function() return { x = 0, y = 0, z = 0 } end,
    }
end

-- ── F-Q-1 : UH-1H → canTransportWholeVehicle nil → returns {} ────────────────
ctld.utils.log("INFO", "── F-Q-1 : UH-1H → returns {} ──")
vs._vehicles      = {}
vs._unitToVehicle = {}
local veh1 = makeMockVehicle("M1045 HMMWV TOW", 2, makeMockUnit(10, 0))
vs._vehicles["v1"] = veh1

local transport_uh1 = makeMockTransport("UH-1H", 2)
local ok, err = pcall(function()
    local result = vs:findLoadableVehicles(transport_uh1)
    check("F-Q-1 result count", #result, 0)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-Q-1 crash: %s", tostring(err))
    fail = fail + 1
end

-- ── F-Q-2 : C-130 BLUE + HMMWV BLUE WAITING → returned ───────────────────────
ctld.utils.log("INFO", "── F-Q-2 : C-130 BLUE + HMMWV BLUE in range → returned ──")
vs._vehicles      = {}
vs._unitToVehicle = {}
local hmmwv = makeMockVehicle("M1045 HMMWV TOW", 2, makeMockUnit(50, 0))
vs._vehicles["v_hmmwv"] = hmmwv

local transport_c130_blue = makeMockTransport("C-130", 2)
ok, err = pcall(function()
    local result = vs:findLoadableVehicles(transport_c130_blue)
    check("F-Q-2 result count", #result, 1)
    if result[1] then
        check("F-Q-2 vehicleType", result[1].vehicleType, "M1045 HMMWV TOW")
    end
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-Q-2 crash: %s", tostring(err))
    fail = fail + 1
end

-- ── F-Q-3 : C-130 BLUE + BRDM-2 RED → excluded (coalition) ──────────────────
ctld.utils.log("INFO", "── F-Q-3 : C-130 BLUE + BRDM-2 RED → excluded coalition ──")
vs._vehicles      = {}
vs._unitToVehicle = {}
local brdm = makeMockVehicle("BRDM-2", 1, makeMockUnit(50, 0))
vs._vehicles["v_brdm"] = brdm

ok, err = pcall(function()
    local result = vs:findLoadableVehicles(transport_c130_blue)
    check("F-Q-3 result count (excluded RED)", #result, 0)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-Q-3 crash: %s", tostring(err))
    fail = fail + 1
end

-- ── F-Q-4 : C-130 BLUE + unknown type → excluded (type) ─────────────────────
ctld.utils.log("INFO", "── F-Q-4 : C-130 BLUE + unknown type → excluded ──")
vs._vehicles      = {}
vs._unitToVehicle = {}
local unknownVeh = makeMockVehicle("T-72B", 2, makeMockUnit(50, 0))
vs._vehicles["v_t72"] = unknownVeh

ok, err = pcall(function()
    local result = vs:findLoadableVehicles(transport_c130_blue)
    check("F-Q-4 result count (excluded type)", #result, 0)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-Q-4 crash: %s", tostring(err))
    fail = fail + 1
end

-- Restore vehicle spawner
vs._vehicles      = _savedVehicles
vs._unitToVehicle = _savedUnitToVehicle

-- ============================================================
-- refreshRequestEquipmentSection tests (F-Q-5 and F-Q-6)
-- ============================================================

local cm  = CTLDCrateManager.getInstance()
local mm  = ctld.MenuManager:getInstance()

-- Save state
local _savedProcessed     = cm._processedCrates
local _savedInAir         = ctld.utils.inAir
local _origUnitGetByName  = Unit.getByName
local _origZmGetZones     = CTLDZoneManager.getInstance().getLogisticZonesAtPoint
local _savedMenus         = mm.menus

-- Mock processedCrates with one singleCrate: HMMWV TOW (loadable for C-130 BLUE)
cm._processedCrates = {
    ["Vehicles"] = {
        singleCrates = {
            {
                singleCrate = { unit = "M1045 HMMWV TOW", desc = "HMMWV TOW", side = nil, isJTAC = false },
                singleTypeSet = nil,
            }
        },
        mixedSets = {},
    }
}

-- Mock ctld.utils.inAir → always false (transport on ground)
ctld.utils.inAir = function() return false end

-- Mock Unit.getByName → mock transport unit
local mockTransportUnit = {
    isExist    = function() return true end,
    getPoint   = function() return { x = 0, y = 0, z = 0 } end,
    getGroup   = function()
        return { getID = function() return 9999 end }
    end,
    getCountry = function() return 2 end,
}
Unit.getByName = function(name)
    if name == "mock_transport" then return mockTransportUnit end
    return _origUnitGetByName(name)
end

-- Mock CTLDZoneManager:getLogisticZonesAtPoint → one logistic zone
local mockZone = { name = "LGZ_MOCK", active = true, isAlive = function() return true end }
CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function(self, point, coa, key)
    return { mockZone }
end

-- Captured addCommand calls
local capturedCmds = {}
local mockMenu = {
    clearBranch = function() end,
    addSubMenu  = function() end,
    addCommand  = function(self, path, name, fn, args, opts)
        table.insert(capturedCmds, { path = path, name = name, fn = fn, args = args })
    end,
    refresh     = function() end,
}

-- ── F-Q-5 : C-130 playerObj (canTransportWholeVehicle) → spawnAsVehicle=true ─
ctld.utils.log("INFO", "── F-Q-5 : C-130 → spawnAsVehicle=true ──")
capturedCmds = {}
mm.menus = { [9999] = mockMenu }

local playerC130 = {
    isTransport = true,
    typeName    = "C-130",
    groupId     = 9999,
    unitName    = "mock_transport",
    coalition   = 2,
}

ok, err = pcall(function()
    cm:refreshRequestEquipmentSection(playerC130)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-Q-5 crash: %s", tostring(err))
    fail = fail + 1
else
    local found = false
    local spawnAsVehicleVal = nil
    for _, cmd in ipairs(capturedCmds) do
        if cmd.args and cmd.args.unit == "M1045 HMMWV TOW" then
            found = true
            spawnAsVehicleVal = cmd.args.spawnAsVehicle
            break
        end
    end
    checkTrue("F-Q-5 command registered for HMMWV", found)
    check("F-Q-5 spawnAsVehicle=true", spawnAsVehicleVal, true)
end

-- ── F-Q-6 : UH-1H playerObj (no canTransportWholeVehicle) → spawnAsVehicle=false
ctld.utils.log("INFO", "── F-Q-6 : UH-1H → spawnAsVehicle=false ──")
capturedCmds = {}
mm.menus = { [9999] = mockMenu }

local playerUH1H = {
    isTransport = true,
    typeName    = "UH-1H",
    groupId     = 9999,
    unitName    = "mock_transport",
    coalition   = 2,
}

ok, err = pcall(function()
    cm:refreshRequestEquipmentSection(playerUH1H)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-Q-6 crash: %s", tostring(err))
    fail = fail + 1
else
    local found = false
    local spawnAsVehicleVal = nil
    for _, cmd in ipairs(capturedCmds) do
        if cmd.args and cmd.args.unit == "M1045 HMMWV TOW" then
            found = true
            spawnAsVehicleVal = cmd.args.spawnAsVehicle
            break
        end
    end
    checkTrue("F-Q-6 command registered for HMMWV", found)
    check("F-Q-6 spawnAsVehicle=false", spawnAsVehicleVal, false)
end

-- ── Restore all ───────────────────────────────────────────────────────────────
cm._processedCrates  = _savedProcessed
ctld.utils.inAir     = _savedInAir
Unit.getByName       = _origUnitGetByName
CTLDZoneManager.getInstance().getLogisticZonesAtPoint = _origZmGetZones
mm.menus             = _savedMenus

cfg.settings["capabilitiesByType"]                   = _savedCaps
cfg.settings["maximumDistancePackableUnitsSearch"]   = _savedDist
cfg.settings["debug"]                                = _saved_debug

-- ── Final result ──────────────────────────────────────────────────────────────
local total = pass + fail
local msg = string.format(
    "[FQ] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — see CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_FQ_RUNNING = false
return "TAG=FQ_VEHICLE_WHOLE_TRANSPORT | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
