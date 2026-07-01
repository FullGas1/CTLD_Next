---@diagnostic disable
-- =============================================================================
-- AUTO — CL-10: addPlayerAircraftByType gate
-- =============================================================================
-- F-CL10-1 : addPlayerAircraftByType=true  → tout joueur UH-1H obtient le menu
-- F-CL10-2 : addPlayerAircraftByType=false + unitName dans transportPilotNames
--            → menu construit
-- F-CL10-3 : addPlayerAircraftByType=false + unitName absent de transportPilotNames
--            → menu NON construit (early return)
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[CL10] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_CL10_RUNNING then
    trigger.action.outText("[CL10] already running.", 10)
    return Witchcraft
end
_SCN_CL10_RUNNING = true

do  -- isolation scope
trigger.action.outText("[CL10] START — addPlayerAircraftByType gate", 8)

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

-- ── Save config state ─────────────────────────────────────────────────────────
local _savedByType   = cfg.settings["addPlayerAircraftByType"]
local _savedPilots   = cfg.settings["transportPilotNames"]

-- ── Mock unit ────────────────────────────────────────────────────────────────
local function makeUnit(name, typeName)
    local grp = {
        getID   = function() return 42 end,
        getName = function() return "TestGroup" end,
    }
    return {
        isExist       = function() return true end,
        getPlayerName = function() return "TestPilot" end,
        getName       = function() return name end,
        getTypeName   = function() return typeName end,
        getGroup      = function() return grp end,
        getCoalition  = function() return 2 end,
    }
end

-- ── Mock CTLDPlayerManager.buildMenu (spy) ───────────────────────────────────
local _menuBuilt = false
local pm = CTLDPlayerManager.getInstance()
local _origBuildMenu = pm.buildMenu
pm.buildMenu = function(self, playerObj)
    _menuBuilt = true
end

-- ── F-CL10-1 : addPlayerAircraftByType=true → menu construit ────────────────
ctld.utils.log("INFO", "── F-CL10-1 : addPlayerAircraftByType=true ──")
cfg.settings["addPlayerAircraftByType"] = true
cfg.settings["transportPilotNames"]     = { "other_slot" }

_menuBuilt = false
local ok, err = pcall(function()
    pm:onPlayerEnterUnit({ initiator = makeUnit("uh1h_slot_1", "UH-1H") })
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-CL10-1 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-CL10-1 menu built when addPlayerAircraftByType=true", _menuBuilt, true)

-- ── F-CL10-2 : addPlayerAircraftByType=false + nom dans liste → menu construit
ctld.utils.log("INFO", "── F-CL10-2 : false + unitName in transportPilotNames ──")
cfg.settings["addPlayerAircraftByType"] = false
cfg.settings["transportPilotNames"]     = { "uh1h_slot_whitelisted", "other_slot" }

_menuBuilt = false
ok, err = pcall(function()
    pm:onPlayerEnterUnit({ initiator = makeUnit("uh1h_slot_whitelisted", "UH-1H") })
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-CL10-2 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-CL10-2 menu built when unit in whitelist", _menuBuilt, true)

-- ── F-CL10-3 : addPlayerAircraftByType=false + nom absent → pas de menu ──────
ctld.utils.log("INFO", "── F-CL10-3 : false + unitName NOT in transportPilotNames ──")
cfg.settings["addPlayerAircraftByType"] = false
cfg.settings["transportPilotNames"]     = { "other_slot" }

_menuBuilt = false
ok, err = pcall(function()
    pm:onPlayerEnterUnit({ initiator = makeUnit("uh1h_slot_unlisted", "UH-1H") })
end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] F-CL10-3 crash: %s", tostring(err))
    fail = fail + 1
end
check("F-CL10-3 menu NOT built when unit not in whitelist", _menuBuilt, false)

-- ── Restore ───────────────────────────────────────────────────────────────────
cfg.settings["addPlayerAircraftByType"] = _savedByType
cfg.settings["transportPilotNames"]     = _savedPilots
cfg.settings["debug"]                   = _saved_debug
pm.buildMenu                            = _origBuildMenu

-- ── Final result ──────────────────────────────────────────────────────────────
local total = pass + fail
local msg = string.format(
    "[CL10] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — see CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_CL10_RUNNING = false
return "TAG=CL10_ADD_PLAYER_BY_TYPE | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
