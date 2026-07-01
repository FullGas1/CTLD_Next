---@diagnostic disable
-- =============================================================================
-- AUTO — B3: loadCrateFromMenu config guard
-- =============================================================================
-- Verifies that CTLDCrateManager respects loadCrateFromMenu:
--   • refreshLoadCrateSection  : early-returns when false (clears no branch)
--   • buildMenuSection         : skips "Load Crate" submenu creation when false
--   • refreshCrateFlightSection: skips setBranchEnabled("Load Crate") when false
--
-- F-B3-1 : refreshLoadCrateSection — loadCrateFromMenu=true  → clearBranch called
-- F-B3-2 : refreshLoadCrateSection — loadCrateFromMenu=false → early-return (no clearBranch)
-- F-B3-3 : buildMenuSection        — loadCrateFromMenu=true  → addSubMenu "Load Crate" called
-- F-B3-4 : buildMenuSection        — loadCrateFromMenu=false → addSubMenu "Load Crate" NOT called
-- F-B3-5 : refreshCrateFlightSection — loadCrateFromMenu=false → setBranchEnabled "Load Crate" NOT called
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[B3] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_B3_RUNNING then
    trigger.action.outText("[B3] already running.", 10)
    return Witchcraft
end
_SCN_B3_RUNNING = true

do  -- isolation scope
trigger.action.outText("[B3] START — loadCrateFromMenu config guard", 8)

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

-- ── Shared mocks ─────────────────────────────────────────────────────────────

local fakePlayer = {
    unitName    = "TestUnit_B3",
    groupId     = 998,
    typeName    = "UH-1H",
    isTransport = true,
}

local fakeUnit = {
    isExist  = function() return true end,
    getPoint = function() return { x=0, y=0, z=0 } end,
}
local _origGetByName = Unit.getByName
Unit.getByName = function(name)
    if name == fakePlayer.unitName then return fakeUnit end
    return _origGetByName(name)
end

local _origInAir = ctld.utils.inAir
ctld.utils.inAir = function() return false end

-- Menu mock: tracks clearBranch, addSubMenu, setBranchEnabled calls
local _clearBranchCalled   = false
local _addSubMenuArgs      = {}   -- list of last path elements
local _setBranchCalled     = {}   -- [last path element] = enabled

local mockMenu = {
    clearBranch       = function(self, path)
        _clearBranchCalled = true
    end,
    addSubMenu        = function(self, path, name, opts)
        table.insert(_addSubMenuArgs, name)
    end,
    addCommand        = function(self, path, name, fn, arg) end,
    setBranchEnabled  = function(self, path, enabled)
        local key = path[#path]
        _setBranchCalled[key] = enabled
    end,
    refresh           = function(self) end,
}

local mockMM = { getMenuByGroupId = function(self, gid) return mockMenu end }
local _origMMGetInstance = ctld.MenuManager.getInstance
ctld.MenuManager.getInstance = function() return mockMM end

local mgr = CTLDCrateManager.getInstance()

-- Stub heavy sub-calls in buildMenuSection to isolate the guards under test
local _origRefreshReqEq  = mgr.refreshRequestEquipmentSection
local _origRefreshLoad   = mgr.refreshLoadCrateSection
local _origRefreshUnpack = mgr.refreshUnpackSection
local _origRefreshFlight = mgr.refreshCrateFlightSection

mgr.refreshRequestEquipmentSection = function() end
-- refreshLoadCrateSection is under test — keep original
mgr.refreshUnpackSection            = function() end
mgr.refreshCrateFlightSection       = function() end   -- called at end of buildMenuSection

-- CTLDVehicleSpawner stub (called by buildMenuSection when enablePackingVehicles)
local _origVSGetInstance = CTLDVehicleSpawner.getInstance
CTLDVehicleSpawner.getInstance = function()
    return { refreshPackSection = function() end }
end

-- ── F-B3-1 : refreshLoadCrateSection — loadCrateFromMenu=true ────────────────
ctld.utils.log("INFO", "── F-B3-1 : refreshLoadCrateSection — loadCrateFromMenu=true ──")
_clearBranchCalled = false
cfg.settings["loadCrateFromMenu"] = true

local ok, err = pcall(function()
    -- Temporarily stub getCratesInRange to avoid scan side-effects
    local _origGCIR = mgr.getCratesInRange
    mgr.getCratesInRange = function() return {} end
    mgr:refreshLoadCrateSection(fakePlayer)
    mgr.getCratesInRange = _origGCIR
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-B3-1 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-B3-1 clearBranch called when loadCrateFromMenu=true", _clearBranchCalled, true)

-- ── F-B3-2 : refreshLoadCrateSection — loadCrateFromMenu=false ───────────────
ctld.utils.log("INFO", "── F-B3-2 : refreshLoadCrateSection — loadCrateFromMenu=false ──")
_clearBranchCalled = false
cfg.settings["loadCrateFromMenu"] = false

ok, err = pcall(function()
    mgr:refreshLoadCrateSection(fakePlayer)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-B3-2 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-B3-2 clearBranch NOT called when loadCrateFromMenu=false", _clearBranchCalled, false)

-- ── F-B3-3 : buildMenuSection — loadCrateFromMenu=true ───────────────────────
ctld.utils.log("INFO", "── F-B3-3 : buildMenuSection — loadCrateFromMenu=true ──")
_addSubMenuArgs = {}
cfg.settings["loadCrateFromMenu"] = true

-- refreshLoadCrateSection must be stubbed here (its guard is already tested above)
mgr.refreshLoadCrateSection = function() end

ok, err = pcall(function()
    mgr:buildMenuSection(fakePlayer, mockMenu)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-B3-3 crash: %s", tostring(err))
    fail = fail + 1
end
local LOAD_CRATE = ctld.tr("Load Crate")
local loadCrateFound = false
for _, name in ipairs(_addSubMenuArgs) do
    if name == LOAD_CRATE then loadCrateFound = true end
end
check("F-B3-3 addSubMenu 'Load Crate' called when loadCrateFromMenu=true", loadCrateFound, true)

-- ── F-B3-4 : buildMenuSection — loadCrateFromMenu=false ──────────────────────
ctld.utils.log("INFO", "── F-B3-4 : buildMenuSection — loadCrateFromMenu=false ──")
_addSubMenuArgs = {}
cfg.settings["loadCrateFromMenu"] = false

ok, err = pcall(function()
    mgr:buildMenuSection(fakePlayer, mockMenu)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-B3-4 crash: %s", tostring(err))
    fail = fail + 1
end
loadCrateFound = false
for _, name in ipairs(_addSubMenuArgs) do
    if name == LOAD_CRATE then loadCrateFound = true end
end
check("F-B3-4 addSubMenu 'Load Crate' NOT called when loadCrateFromMenu=false", loadCrateFound, false)

-- ── F-B3-5 : refreshCrateFlightSection — loadCrateFromMenu=false ─────────────
ctld.utils.log("INFO", "── F-B3-5 : refreshCrateFlightSection — loadCrateFromMenu=false ──")
_setBranchCalled = {}
cfg.settings["loadCrateFromMenu"] = false

-- Restore original refreshCrateFlightSection for this test
mgr.refreshCrateFlightSection = _origRefreshFlight

ok, err = pcall(function()
    mgr:refreshCrateFlightSection(fakePlayer)
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-B3-5 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-B3-5 setBranchEnabled 'Load Crate' NOT called when loadCrateFromMenu=false",
    _setBranchCalled[LOAD_CRATE], nil)

-- ── Restore ───────────────────────────────────────────────────────────────────
cfg.settings["loadCrateFromMenu"]   = true  -- restore to default
cfg.settings["debug"]               = _saved_debug
Unit.getByName                       = _origGetByName
ctld.utils.inAir                     = _origInAir
ctld.MenuManager.getInstance         = _origMMGetInstance
CTLDVehicleSpawner.getInstance       = _origVSGetInstance
mgr.refreshRequestEquipmentSection   = _origRefreshReqEq
mgr.refreshLoadCrateSection          = _origRefreshLoad
mgr.refreshUnpackSection             = _origRefreshUnpack
mgr.refreshCrateFlightSection        = _origRefreshFlight

-- ── Final result ──────────────────────────────────────────────────────────────
local total = pass + fail
local msg = string.format(
    "[B3] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — see CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_B3_RUNNING = false
return "TAG=B3_LOAD_CRATE_FROM_MENU | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
