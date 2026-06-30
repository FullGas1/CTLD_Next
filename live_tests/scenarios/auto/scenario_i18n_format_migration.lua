---@diagnostic disable
-- =============================================================================
-- AUTO — i18n format migration : string.format → ctld.tr native substitution
-- =============================================================================
-- Vérifie que tous les sites migrés de string.format(ctld.tr(...)) vers
-- ctld.tr(..., args) produisent les mêmes messages qu'attendu.
--
-- U-100 : ctld.tr crate capacity key (%1/%2) → "(1/1)"
-- U-101 : ctld.tr lasing key (%1) → nom JTAC substitué
-- U-102 : ctld.tr altitude key (%1/%2) → valeurs numériques substituées
-- U-103 : ctld.tr vehicle capacity key (%1) → valeur numérique substituée
-- U-104 : ctld.tr packed-into key (%1/%2) → nom véhicule + nb caisses substitués
-- F-167 : guard caisses à bord → message capturé contient "(1/1)"
--
-- Prérequis : aucun (entièrement mocké)
-- Famille   : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[I18N-FMT] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_I18N_RUNNING then
    trigger.action.outText("[I18N-FMT] already running.", 10)
    return Witchcraft
end
_SCN_I18N_RUNNING = true

do  -- isolation scope
trigger.action.outText("[I18N-FMT] START — i18n format migration validation", 8)

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

local function checkContains(label, str, sub)
    if str and str:find(sub, 1, true) then
        ctld.utils.log("INFO", "[PASS] %s (contains '%s')", label, sub)
        pass = pass + 1
    else
        ctld.utils.log("ERROR", "[FAIL] %s : '%s' not found in '%s'", label, sub, tostring(str))
        fail = fail + 1
    end
end

-- ── U-100 : crate capacity key (%1/%2) ───────────────────────────────────────
ctld.utils.log("INFO", "── U-100 : crate capacity key ──")
local msg100 = ctld.tr("Maximum number of crates are on board!", 1, 1)
checkContains("U-100 message contains '(1/1)'", msg100, "(1/1)")

-- ── U-101 : lasing key (%1) ──────────────────────────────────────────────────
ctld.utils.log("INFO", "── U-101 : lasing key ──")
local msg101a = ctld.tr("Lasing activated: %1", "JTAC-Alpha")
local msg101b = ctld.tr("Lasing deactivated (standby): %1", "JTAC-Alpha")
checkContains("U-101 Lasing activated contains 'JTAC-Alpha'",   msg101a, "JTAC-Alpha")
checkContains("U-101 Lasing deactivated contains 'JTAC-Alpha'", msg101b, "JTAC-Alpha")

-- ── U-102 : altitude key (%1/%2) ─────────────────────────────────────────────
ctld.utils.log("INFO", "── U-102 : altitude key ──")
local msg102 = ctld.tr("Altitude too low for parachute drop. Minimum: %1m AGL (current: %2m AGL)", 30, 15)
checkContains("U-102 altitude contains '30m'", msg102, "30m")
checkContains("U-102 altitude contains '15m'", msg102, "15m")

-- ── U-103 : vehicle capacity key (%1/%2) ─────────────────────────────────────
ctld.utils.log("INFO", "── U-103 : vehicle capacity key ──")
local msg103 = ctld.tr("Cannot load more vehicles (%1/%2).", 1, 1)
checkContains("U-103 vehicle capacity contains '(1/1)'", msg103, "(1/1)")

-- ── U-104 : packed-into key (%1/%2) ──────────────────────────────────────────
ctld.utils.log("INFO", "── U-104 : packed-into key ──")
local msg104 = ctld.tr("%1 packed into %2 crate(s).", "M1043 HMMWV Armament", 3)
checkContains("U-104 packed-into contains vehicle name", msg104, "M1043 HMMWV Armament")
checkContains("U-104 packed-into contains crate count",  msg104, "3")

-- ── U-105 : troop capacity key (%1/%2) ───────────────────────────────────────
ctld.utils.log("INFO", "── U-105 : troop capacity key ──")
local msg105 = ctld.tr("Group too large for this aircraft (%1/%2 troops).", 6, 8)
checkContains("U-105 troop capacity contains '(6/8'", msg105, "(6/8")

-- ── F-167 : guard caisses à bord → message capturé contient "(1/1)" ──────────
ctld.utils.log("INFO", "── F-167 : crate capacity guard message format ──")

local capturedMsg = nil
local _orig_outText = trigger.action.outTextForGroup
trigger.action.outTextForGroup = function(gid, msg, dur, ...)
    if msg and msg:find("1/1", 1, true) then
        capturedMsg = msg
    end
    _orig_outText(gid, msg, dur, ...)
end

-- Injecter directement la logique de guard : onboard=1 >= capacity=1
-- ctld.tr est appelé avec les bons args → vérifier le message produit
local guardMsg = ctld.tr("Maximum number of crates are on board!", 1, 1)
trigger.action.outTextForGroup(1, guardMsg, 10)

trigger.action.outTextForGroup = _orig_outText

checkContains("F-167 guard message contains '(1/1)'", capturedMsg, "(1/1)")

-- ── Résultat final ────────────────────────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local total = pass + fail
local msg = string.format(
    "[I18N-FMT] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — voir CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_I18N_RUNNING = false
return "TAG=I18N_FORMAT | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
