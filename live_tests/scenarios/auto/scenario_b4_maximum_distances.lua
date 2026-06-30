---@diagnostic disable
-- =============================================================================
-- AUTO — B4: maximumSearchDistance câblé dans AttackNearestEnemyOnLos
-- =============================================================================
-- Vérifie que le rayon de recherche passé à world.searchObjects correspond
-- à ctld.gs("maximumSearchDistance") et non au hardcode 10000.
--
-- F-B4-1 : rayon = valeur par défaut (4000) quand config = 4000
-- F-B4-2 : rayon = 1500 quand config = 1500
-- F-B4-3 : rayon = 10000 (fallback) quand config = nil
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[B4] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_B4_RUNNING then
    trigger.action.outText("[B4] already running.", 10)
    return Witchcraft
end
_SCN_B4_RUNNING = true

do  -- isolation scope
trigger.action.outText("[B4] START — maximumSearchDistance config guard", 8)

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

-- ── Mock world.searchObjects — captures radius argument ──────────────────────
local _capturedRadius = nil
local _origSearchObjects = world.searchObjects
world.searchObjects = function(category, volume, fn)
    _capturedRadius = volume.params and volume.params.radius
    -- return immediately without iterating (no real units)
end

-- ── Mock Group.getByName + group helpers ─────────────────────────────────────
local fakeCtrl = {
    setOption = function() end,
    setTask    = function() end,
}
local fakeGroup = {
    isExist    = function() return true end,
    getController = function() return fakeCtrl end,
}
local _origGroupGetByName = Group.getByName
Group.getByName = function(name)
    if name == "TestGroup_B4" then return fakeGroup end
    return _origGroupGetByName(name)
end

-- ── Mock timer.scheduleFunction — execute callback immediately ────────────────
local _origSchedule = timer.scheduleFunction
timer.scheduleFunction = function(fn, arg, t)
    fn(arg)
end

-- ── Mock ctld.utils.buildWP ───────────────────────────────────────────────────
local _origBuildWP = ctld.utils.buildWP
ctld.utils.buildWP = function() return { type = "Turning Point" } end

-- ── Helper: trigger _assignPostSpawnTask with AttackNearestEnemyOnLos ────
local mgr    = CTLDTroopManager.getInstance()
local spawnPt = { x = 0, y = 0, z = 0 }

local function runTask(searchDist)
    _capturedRadius = nil
    cfg.settings["maximumSearchDistance"] = searchDist
    local ok, err = pcall(function()
        mgr:_assignPostSpawnTask(
            "TestGroup_B4",
            spawnPt,
            coalition.side.BLUE,
            { task = "AttackNearestEnemyOnLos" }
        )
    end)
    if not ok then
        ctld.utils.log("ERROR", "[FAIL] _assignPostSpawnTask crash: %s", tostring(err))
        fail = fail + 1
    end
end

-- ── F-B4-1 : rayon = 4000 (valeur par défaut config) ─────────────────────────
ctld.utils.log("INFO", "── F-B4-1 : maximumSearchDistance = 4000 ──")
runTask(4000)
check("F-B4-1 radius = 4000", _capturedRadius, 4000)

-- ── F-B4-2 : rayon = 1500 (valeur custom) ────────────────────────────────────
ctld.utils.log("INFO", "── F-B4-2 : maximumSearchDistance = 1500 ──")
runTask(1500)
check("F-B4-2 radius = 1500", _capturedRadius, 1500)

-- ── F-B4-3 : rayon = 10000 (fallback quand config = nil) ─────────────────────
ctld.utils.log("INFO", "── F-B4-3 : maximumSearchDistance = nil → fallback 10000 ──")
cfg.settings["maximumSearchDistance"] = nil
_capturedRadius = nil
local ok, err = pcall(function()
    mgr:_assignPostSpawnTask(
        "TestGroup_B4",
        spawnPt,
        coalition.side.BLUE,
        { task = "AttackNearestEnemyOnLos" }
    )
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-B4-3 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-B4-3 radius = 10000 (fallback)", _capturedRadius, 10000)

-- ── Restore ───────────────────────────────────────────────────────────────────
cfg.settings["maximumSearchDistance"] = 4000  -- restore default
cfg.settings["debug"]                 = _saved_debug
world.searchObjects                   = _origSearchObjects
Group.getByName                       = _origGroupGetByName
timer.scheduleFunction                = _origSchedule
ctld.utils.buildWP                    = _origBuildWP

-- ── Final result ──────────────────────────────────────────────────────────────
local total = pass + fail
local msg = string.format(
    "[B4] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — see CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_B4_RUNNING = false
return "TAG=B4_MAXIMUM_DISTANCES | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
