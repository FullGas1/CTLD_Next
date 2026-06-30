---@diagnostic disable
-- =============================================================================
-- INTERACTIVE — Crate Commands menu: sol/vol visual check
-- =============================================================================
-- Step-by-step visual verification of Crate Commands menu visibility.
--
-- Prerequisites:
--   - Player slot: UH-1H BLUE (canParachuteDrop=true, canSlingload=true)
--   - At least one CTLD logistic zone with crates available
--   - enableCrates = true, enablePackingVehicles = true in config
--
-- Protocol:
--   Step 1 — Player on ground near logistics → check ground menu items visible
--   Step 2 — Player has taken off → check air menu items visible, ground hidden
--   Step 3 — Player has landed → check ground items restored
--
-- Family : interactive
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[CMFV-VIS] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[CMFV-VIS]"
local STEP_N = "_CMFV_VIS_STEP"
_G[STEP_N]  = _G[STEP_N] or 1
local step  = _G[STEP_N]

local START = os.date("%Y-%m-%d %H:%M:%S")
trigger.action.outText(TAG .. " ==== START " .. START .. " | step=" .. step .. " ====", 15)
ctld.utils.log("INFO", TAG .. " START step=" .. step)

-- ── STEP 1 — Ground check ─────────────────────────────────────────────────────
if step == 1 then
    trigger.action.outText(
        TAG .. " STEP 1 — GROUND CHECK\n" ..
        "Confirm in F10 menu → CTLD → Crate Commands:\n" ..
        "  ✅ VISIBLE  : Load Crate\n" ..
        "  ✅ VISIBLE  : Drop Crate(s)\n" ..
        "  ✅ VISIBLE  : Unpack Crate\n" ..
        "  ✅ VISIBLE  : List Nearby Crates\n" ..
        "  ✅ VISIBLE  : Pack Vehicle\n" ..
        "  ❌ HIDDEN   : Parachute Crates\n" ..
        "  ❌ HIDDEN   : Release Slingload\n" ..
        "  ❌ HIDDEN   : Cut Slingload\n" ..
        "\nLoad a crate via CTLD menu, then TAKE OFF.\n" ..
        "Re-inject this script after takeoff for Step 2.",
        60)
    ctld.utils.log("INFO", TAG .. " step=1 — awaiting player takeoff with crate loaded")
    _G[STEP_N] = 2

-- ── STEP 2 — Air check ───────────────────────────────────────────────────────
elseif step == 2 then
    trigger.action.outText(
        TAG .. " STEP 2 — AIR CHECK (crate loaded via CTLD)\n" ..
        "Confirm in F10 menu → CTLD → Crate Commands:\n" ..
        "  ❌ HIDDEN   : Load Crate\n" ..
        "  ❌ HIDDEN   : Drop Crate(s)\n" ..
        "  ❌ HIDDEN   : Unpack Crate\n" ..
        "  ❌ HIDDEN   : List Nearby Crates\n" ..
        "  ❌ HIDDEN   : Pack Vehicle\n" ..
        "  ✅ VISIBLE  : Parachute Crates   (crate on board → enabled)\n" ..
        "  ❌ HIDDEN   : Release Slingload  (aucun slingload CTLD actif)\n" ..
        "  ❌ HIDDEN   : Cut Slingload      (aucun slingload CTLD actif)\n" ..
        "\nNow LAND (without parachuting) then re-inject for Step 3.",
        60)
    ctld.utils.log("INFO", TAG .. " step=2 — awaiting player land")
    _G[STEP_N] = 3

-- ── STEP 3 — Land restore check ──────────────────────────────────────────────
elseif step == 3 then
    trigger.action.outText(
        TAG .. " STEP 3 — GROUND RESTORE CHECK\n" ..
        "Confirm in F10 menu → CTLD → Crate Commands:\n" ..
        "  ✅ VISIBLE  : Load Crate\n" ..
        "  ✅ VISIBLE  : Drop Crate(s)\n" ..
        "  ✅ VISIBLE  : Unpack Crate\n" ..
        "  ✅ VISIBLE  : List Nearby Crates\n" ..
        "  ✅ VISIBLE  : Pack Vehicle\n" ..
        "  ❌ HIDDEN   : Parachute Crates\n" ..
        "  ❌ HIDDEN   : Release Slingload\n" ..
        "  ❌ HIDDEN   : Cut Slingload\n" ..
        "\nIf all correct → scenario COMPLETE. Re-inject to reset.",
        60)
    ctld.utils.log("INFO", TAG .. " step=3 — visual check complete")
    _G[STEP_N] = 1

else
    trigger.action.outText(TAG .. " unknown step=" .. step .. " — reset", 15)
    _G[STEP_N] = 1
end

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
trigger.action.outText(TAG .. " ✅ DONE", 20, true)
return TAG .. " step=" .. step .. " injected"
