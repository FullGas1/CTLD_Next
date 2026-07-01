---@diagnostic disable
-- =============================================================================
-- AUTO — Feature O: extractableGroups → CTLDTroopManager._droppedGroups (INIT-E)
-- =============================================================================
-- F-O-1 : existing group coalition 2 → inserted into _droppedGroups[2]
-- F-O-2 : non-existent group name    → skipped (no insertion, log WARN)
-- F-O-3 : two groups coalition 1     → both inserted into _droppedGroups[1]
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FO] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_FO_RUNNING then
    trigger.action.outText("[FO] already running.", 10)
    return Witchcraft
end
_SCN_FO_RUNNING = true

do  -- isolation scope
trigger.action.outText("[FO] START — extractableGroups INIT-E", 8)

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

local function checkTrue(label, cond)
    check(label, cond, true)
end

-- ── Save config state ─────────────────────────────────────────────────────────
local _savedExtractable = cfg.settings["extractableGroups"]

-- ── Mock Group.getByName ──────────────────────────────────────────────────────
local _origGroupGetByName = Group.getByName

local _mockGroups = {}
local function makeMockGroup(name, coa)
    return {
        isExist     = function() return true end,
        getName     = function() return name end,
        getCoalition = function() return coa end,
    }
end
_mockGroups["blue_squad_1"] = makeMockGroup("blue_squad_1", 2)
_mockGroups["red_squad_1"]  = makeMockGroup("red_squad_1",  1)
_mockGroups["red_squad_2"]  = makeMockGroup("red_squad_2",  1)

Group.getByName = function(name)
    return _mockGroups[name] or nil
end

-- ── Save and clear _droppedGroups ─────────────────────────────────────────────
local tm = CTLDTroopManager.getInstance()
local _savedDropped = tm._droppedGroups
tm._droppedGroups = { [1] = {}, [2] = {} }

-- ── F-O-1 : existing blue group → _droppedGroups[2] ─────────────────────────
ctld.utils.log("INFO", "── F-O-1 : existing group coalition 2 ──")
cfg.settings["extractableGroups"] = { "blue_squad_1" }

local core = CTLDCoreManager.getInstance()
local ok, err = pcall(function() core:_initExtractableGroups() end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-O-1 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-O-1 group inserted into _droppedGroups[2]", #tm._droppedGroups[2], 1)
check("F-O-1 correct groupName", tm._droppedGroups[2][1], "blue_squad_1")

-- ── F-O-2 : non-existent group → skipped ─────────────────────────────────────
ctld.utils.log("INFO", "── F-O-2 : non-existent group skipped ──")
tm._droppedGroups = { [1] = {}, [2] = {} }
cfg.settings["extractableGroups"] = { "ghost_unit_999" }

ok, err = pcall(function() core:_initExtractableGroups() end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-O-2 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-O-2 _droppedGroups[1] still empty", #tm._droppedGroups[1], 0)
check("F-O-2 _droppedGroups[2] still empty", #tm._droppedGroups[2], 0)

-- ── F-O-3 : two RED groups → both in _droppedGroups[1] ───────────────────────
ctld.utils.log("INFO", "── F-O-3 : two groups coalition 1 ──")
tm._droppedGroups = { [1] = {}, [2] = {} }
cfg.settings["extractableGroups"] = { "red_squad_1", "red_squad_2" }

ok, err = pcall(function() core:_initExtractableGroups() end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-O-3 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-O-3 two groups in _droppedGroups[1]", #tm._droppedGroups[1], 2)

local found1, found2 = false, false
for _, n in ipairs(tm._droppedGroups[1]) do
    if n == "red_squad_1" then found1 = true end
    if n == "red_squad_2" then found2 = true end
end
checkTrue("F-O-3 red_squad_1 present", found1)
checkTrue("F-O-3 red_squad_2 present", found2)

-- ── Restore ───────────────────────────────────────────────────────────────────
cfg.settings["extractableGroups"] = _savedExtractable
cfg.settings["debug"]             = _saved_debug
tm._droppedGroups                 = _savedDropped
Group.getByName                   = _origGroupGetByName

-- ── Final result ──────────────────────────────────────────────────────────────
local total = pass + fail
local msg = string.format(
    "[FO] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — see CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_FO_RUNNING = false
return "TAG=FO_EXTRACTABLE_GROUPS | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
