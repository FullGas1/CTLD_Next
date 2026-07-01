---@diagnostic disable
-- ============================================================
-- JTAC Toggle Lasing — recette automatique
-- ============================================================
-- Vérifie toggleStandby : basculement standbyMode, arrêt/reprise
-- lasing, labels dynamiques menu, confirmation messages.
-- Famille : auto (aucune intervention humaine)
-- ============================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-TL] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_F_TL_RUNNING then
    trigger.action.outText("[F-TL] already running.", 10)
    return Witchcraft
end
_SCN_F_TL_RUNNING = true

do  -- isolation scope
trigger.action.outText("[F-TL] START — JTAC Toggle Lasing", 8)

local JTAC_NAME  = "mock_jtac_tl"
local GROUP_ID   = 99

-- ── Helpers ──────────────────────────────────────────────────
local passed = 0
local failed = 0
local failures = {}
local function pass(_) passed = passed + 1 end
local function fail(lbl) failed = failed + 1; table.insert(failures, lbl) end
local function check(lbl, cond) if cond then pass(lbl) else fail(lbl) end end

-- ── Mock JTAC setup ──────────────────────────────────────────
local mgr = CTLDJTACManager.getInstance()

-- Register a minimal mock JTAC (no DCS unit, purely state machine)
local mockJTAC = CTLDJTAC:new({
    groupName   = JTAC_NAME,
    coalitionId = 2,
    laserCode   = 1688,
})
mgr.jtacs[JTAC_NAME] = mockJTAC

-- Mock outTextForGroup to capture messages without DCS
local capturedMsgs = {}
local _origOut = trigger.action.outTextForGroup
trigger.action.outTextForGroup = function(gid, msg, _dur)
    table.insert(capturedMsgs, msg)
end

-- Mock _rebuildJTACCommandBranch to avoid menu ops (no real player)
local rebuildCalled = false
local _origRebuild = mgr._rebuildJTACCommandBranch
mgr._rebuildJTACCommandBranch = function(self, gname)
    if gname == JTAC_NAME then rebuildCalled = true end
end

-- Mock startLase to avoid DCS spawn
local startLaseCalled = false
local _origStartLase = mgr.startLase
mgr.startLase = function(self, gname)
    if gname == JTAC_NAME then startLaseCalled = true end
end

-- ── F-TL-1 : standbyMode false → true ───────────────────────
mockJTAC.standbyMode    = false
mockJTAC.currentTarget  = nil
capturedMsgs = {}
rebuildCalled = false

mgr:toggleStandby(JTAC_NAME, GROUP_ID)

check("F-TL-1a standbyMode set to true",  mockJTAC.standbyMode == true)
check("F-TL-1b confirmation msg sent",    #capturedMsgs == 1)
check("F-TL-1c msg contains 'standby'",  capturedMsgs[1] and capturedMsgs[1]:find("standby") ~= nil)
check("F-TL-1d _rebuildJTACCommandBranch called", rebuildCalled == true)

-- ── F-TL-2 : standbyMode true → false ───────────────────────
mockJTAC.standbyMode   = true
capturedMsgs = {}
rebuildCalled = false
startLaseCalled = false

mgr:toggleStandby(JTAC_NAME, GROUP_ID)

check("F-TL-2a standbyMode set to false", mockJTAC.standbyMode == false)
check("F-TL-2b startLase called",         startLaseCalled == true)
check("F-TL-2c confirmation msg sent",    #capturedMsgs == 1)
check("F-TL-2d msg contains 'activated'", capturedMsgs[1] and capturedMsgs[1]:find("activated") ~= nil)
check("F-TL-2e _rebuildJTACCommandBranch called", rebuildCalled == true)

-- ── F-TL-3 : label dynamique selon état ─────────────────────
mockJTAC.standbyMode = false
local labelActive = mockJTAC.standbyMode
    and ctld.tr("Lasing [activate]")
    or  ctld.tr("Lasing [deactivate]")
check("F-TL-3a label when lasing active = [deactivate]",
    labelActive == ctld.tr("Lasing [deactivate]"))

mockJTAC.standbyMode = true
local labelStandby = mockJTAC.standbyMode
    and ctld.tr("Lasing [activate]")
    or  ctld.tr("Lasing [deactivate]")
check("F-TL-3b label when standby = [activate]",
    labelStandby == ctld.tr("Lasing [activate]"))

-- ── F-TL-4 : JTAC inexistant → message erreur ───────────────
capturedMsgs = {}
mgr:toggleStandby("nonexistent_jtac", GROUP_ID)
check("F-TL-4 unknown JTAC → error msg", #capturedMsgs == 1)

-- ── Cleanup ──────────────────────────────────────────────────
mgr.jtacs[JTAC_NAME]             = nil
trigger.action.outTextForGroup   = _origOut
mgr._rebuildJTACCommandBranch    = _origRebuild
mgr.startLase                    = _origStartLase

-- ── Résultat ─────────────────────────────────────────────────
local total = passed + failed
local msg = string.format("[F-TL] %d/%d PASS", passed, total)
if #failures > 0 then msg = msg .. " | FAIL: " .. table.concat(failures, ", ") end
trigger.action.outText(msg, 12, true)
_SCN_F_TL_RUNNING = false
return msg
end  -- do isolation scope
return Witchcraft
