---@diagnostic disable
-- ============================================================
-- JTAC Spot Corrections toggle — recette automatique
-- ============================================================
-- Vérifie toggleSpotCorrections : basculement laseSpotCorrections,
-- labels dynamiques menu, confirmation messages.
-- Famille : auto (aucune intervention humaine)
-- ============================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-SC] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_F_SC_RUNNING then
    trigger.action.outText("[F-SC] already running.", 10)
    return Witchcraft
end
_SCN_F_SC_RUNNING = true

do  -- isolation scope
trigger.action.outText("[F-SC] START — JTAC Spot Corrections toggle", 8)

local JTAC_NAME = "mock_jtac_sc"
local GROUP_ID  = 99

-- ── Helpers ──────────────────────────────────────────────────
local passed = 0
local failed = 0
local failures = {}
local function pass(_) passed = passed + 1 end
local function fail(lbl) failed = failed + 1; table.insert(failures, lbl) end
local function check(lbl, cond) if cond then pass(lbl) else fail(lbl) end end

-- ── Mock JTAC setup ──────────────────────────────────────────
local mgr = CTLDJTACManager.getInstance()

local mockJTAC = CTLDJTAC:new({
    groupName   = JTAC_NAME,
    coalitionId = 2,
    laserCode   = 1688,
})
mgr.jtacs[JTAC_NAME] = mockJTAC

local capturedMsgs = {}
local _origOut = trigger.action.outTextForGroup
trigger.action.outTextForGroup = function(_, msg, _) table.insert(capturedMsgs, msg) end

local rebuildCalled = false
local _origRebuild = mgr._rebuildJTACCommandBranch
mgr._rebuildJTACCommandBranch = function(self, gname)
    if gname == JTAC_NAME then rebuildCalled = true end
end

-- ── F-SC-1 : laseSpotCorrections false → true ───────────────
mockJTAC.laseSpotCorrections = false
capturedMsgs = {}
rebuildCalled = false

mgr:toggleSpotCorrections(JTAC_NAME, GROUP_ID)

check("F-SC-1a laseSpotCorrections set to true",  mockJTAC.laseSpotCorrections == true)
check("F-SC-1b confirmation msg sent",             #capturedMsgs == 1)
check("F-SC-1c msg contains 'activated'",          capturedMsgs[1] and capturedMsgs[1]:find("activated") ~= nil)
check("F-SC-1d _rebuildJTACCommandBranch called",  rebuildCalled == true)

-- ── F-SC-2 : laseSpotCorrections true → false ───────────────
mockJTAC.laseSpotCorrections = true
capturedMsgs = {}
rebuildCalled = false

mgr:toggleSpotCorrections(JTAC_NAME, GROUP_ID)

check("F-SC-2a laseSpotCorrections set to false",  mockJTAC.laseSpotCorrections == false)
check("F-SC-2b confirmation msg sent",             #capturedMsgs == 1)
check("F-SC-2c msg contains 'deactivated'",        capturedMsgs[1] and capturedMsgs[1]:find("deactivated") ~= nil)
check("F-SC-2d _rebuildJTACCommandBranch called",  rebuildCalled == true)

-- ── F-SC-3 : labels dynamiques ──────────────────────────────
mockJTAC.laseSpotCorrections = false
local labelOff = mockJTAC.laseSpotCorrections
    and ctld.tr("Spot Corrections [deactivate]")
    or  ctld.tr("Spot Corrections [activate]")
check("F-SC-3a label when off = [activate]",
    labelOff == ctld.tr("Spot Corrections [activate]"))

mockJTAC.laseSpotCorrections = true
local labelOn = mockJTAC.laseSpotCorrections
    and ctld.tr("Spot Corrections [deactivate]")
    or  ctld.tr("Spot Corrections [activate]")
check("F-SC-3b label when on = [deactivate]",
    labelOn == ctld.tr("Spot Corrections [deactivate]"))

-- ── F-SC-4 : JTAC inexistant → message erreur ───────────────
capturedMsgs = {}
mgr:toggleSpotCorrections("nonexistent_jtac", GROUP_ID)
check("F-SC-4 unknown JTAC → error msg", #capturedMsgs == 1)

-- ── Cleanup ──────────────────────────────────────────────────
mgr.jtacs[JTAC_NAME]           = nil
trigger.action.outTextForGroup = _origOut
mgr._rebuildJTACCommandBranch  = _origRebuild

-- ── Résultat ─────────────────────────────────────────────────
local total = passed + failed
local msg = string.format("[F-SC] %d/%d PASS", passed, total)
if #failures > 0 then msg = msg .. " | FAIL: " .. table.concat(failures, ", ") end
trigger.action.outText(msg, 12, true)
_SCN_F_SC_RUNNING = false
return msg
end  -- do isolation scope
return Witchcraft
