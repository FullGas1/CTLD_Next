---@diagnostic disable
-- =============================================================================
-- AUTO — Crate Commands menu: flight-state visibility (sol/vol split)
-- =============================================================================
-- Verifies that CTLDCrateManager:refreshCrateFlightSection correctly
-- enables/disables menu branches based on in-air state.
--
-- F-168 : ground state — ground items enabled (Load, Drop, Unpack, List, Pack)
-- F-169 : ground state — air items disabled (Parachute, Release, Cut)
-- F-170 : air state    — ground items disabled
-- F-171 : air state    — Parachute Crates enabled when CTLD crate onboard
-- F-172 : air state    — Parachute Crates disabled when no crate onboard
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[CMFV] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_CMFV_RUNNING then
    trigger.action.outText("[CMFV] already running.", 10)
    return Witchcraft
end
_SCN_CMFV_RUNNING = true

do  -- isolation scope
trigger.action.outText("[CMFV] START — Crate menu flight-state visibility", 8)

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

-- Mock player for UH-1H (canParachuteDrop=true, canSlingload=true, cratesEnabled=true)
local fakePlayer = {
    unitName    = "TestUnit_CMFV",
    groupId     = 999,
    typeName    = "UH-1H",
    isTransport = true,
}

-- Mock unit: existence + inAir overridden per test
local fakeUnit = { isExist = function() return true end }
local _origGetByName = Unit.getByName
Unit.getByName = function(name)
    if name == fakePlayer.unitName then return fakeUnit end
    return _origGetByName(name)
end

-- Mock inAir
local _origInAir = ctld.utils.inAir
local _mockInAir = false
ctld.utils.inAir = function(u) return _mockInAir end

-- Menu mock: captures setBranchEnabled calls keyed by last path element
local capturedState = {}
local mockMenu = {
    setBranchEnabled = function(self, path, enabled)
        local key = path[#path]
        capturedState[key] = enabled
    end,
    refresh = function() end,
}
local mockMM = { getMenuByGroupId = function(self, gid) return mockMenu end }
local _origMMGetInstance = ctld.MenuManager.getInstance
ctld.MenuManager.getInstance = function() return mockMM end

-- Helper: run refreshCrateFlightSection and return captured state
local function runRefresh(inAir, cratesOnboard)
    capturedState = {}
    _mockInAir = inAir

    -- Optionally inject a fake loaded crate into CTLDCrateManager.crates
    local mgr      = CTLDCrateManager.getInstance()
    local _origCrates = mgr.crates

    if cratesOnboard > 0 then
        local fakeCrate = {
            isLoadedByCTLD = function() return true end,
            loadedBy       = { getName = function() return fakePlayer.unitName end },
        }
        mgr.crates = { fake1 = fakeCrate }
    else
        mgr.crates = {}
    end

    local ok, err = pcall(function()
        mgr:refreshCrateFlightSection(fakePlayer)
    end)
    mgr.crates = _origCrates

    if not ok then
        ctld.utils.log("ERROR", "[FAIL] refreshCrateFlightSection crash: %s", tostring(err))
        fail = fail + 1
    end
end

local LOAD       = ctld.tr("Load Crate")
local DROP       = ctld.tr("Drop Crate(s)")
local UNPACK     = ctld.tr("Unpack Crate")
local LIST       = ctld.tr("List Nearby Crates")
local PARACHUTE  = ctld.tr("Parachute Crates")
local RELEASE    = ctld.tr("Release Slingload")
local CUT        = ctld.tr("Cut Slingload")

-- ── F-168 : ground state — ground items enabled ───────────────────────────────
ctld.utils.log("INFO", "── F-168 : ground state — ground items enabled ──")
runRefresh(false, 0)
check("F-168.1 Load Crate enabled on ground",    capturedState[LOAD],   true)
check("F-168.2 Drop Crate(s) enabled on ground", capturedState[DROP],   true)
check("F-168.3 Unpack Crate enabled on ground",  capturedState[UNPACK], true)
check("F-168.4 List Nearby Crates enabled",      capturedState[LIST],   true)

-- ── F-169 : ground state — air items disabled ─────────────────────────────────
ctld.utils.log("INFO", "── F-169 : ground state — air items disabled ──")
-- capturedState already from F-168 run (same ground run)
check("F-169.1 Parachute Crates disabled on ground",  capturedState[PARACHUTE], false)
check("F-169.2 Release Slingload disabled on ground", capturedState[RELEASE],   false)
check("F-169.3 Cut Slingload disabled on ground",     capturedState[CUT],       false)

-- ── F-170 : air state — ground items disabled ─────────────────────────────────
ctld.utils.log("INFO", "── F-170 : air state — ground items disabled ──")
runRefresh(true, 0)
check("F-170.1 Load Crate disabled in air",         capturedState[LOAD],   false)
check("F-170.2 Drop Crate(s) disabled in air",      capturedState[DROP],   false)
check("F-170.3 Unpack Crate disabled in air",       capturedState[UNPACK], false)
check("F-170.4 List Nearby Crates disabled in air", capturedState[LIST],   false)

-- ── F-171 : air state — Parachute Crates ON when crate onboard ───────────────
ctld.utils.log("INFO", "── F-171 : air state — Parachute Crates enabled with crate aboard ──")
runRefresh(true, 1)
check("F-171.1 Parachute Crates enabled in air + crate", capturedState[PARACHUTE], true)

-- ── F-172 : air state — Release/Cut Slingload OFF when no slingload active ────
-- Slingload items require inTransitOnSlingload=true; runRefresh injects no such crate.
ctld.utils.log("INFO", "── F-172 : air state — Release/Cut disabled without active slingload ──")
runRefresh(true, 0)
check("F-172.1 Parachute Crates disabled in air + no crate",     capturedState[PARACHUTE], false)
check("F-172.2 Release Slingload disabled: no slingload active", capturedState[RELEASE],   false)
check("F-172.3 Cut Slingload disabled: no slingload active",     capturedState[CUT],       false)

-- ── Restore mocks ─────────────────────────────────────────────────────────────
Unit.getByName              = _origGetByName
ctld.utils.inAir            = _origInAir
ctld.MenuManager.getInstance = _origMMGetInstance

-- ── Final result ──────────────────────────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local total = pass + fail
local msg = string.format(
    "[CMFV] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — see CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_CMFV_RUNNING = false
return "TAG=CRATE_MENU_FLIGHT | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
