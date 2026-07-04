---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_p2_fob_parachute.lua
-- CTLD — FOB auto-unpack depuis parachutage (sous-cas P2)
--
-- Valide :
--   (a) checkSpatialGuards bloque si trop proche d'une LGZ existante
--   (b) quand les guards passent : scene joue + FOB enregistré dans CTLDFOBManager
--
-- Cinématique (3 steps, injection unique) :
--   S1 [auto] Spawn 3 FOB crates LANDED+fromParachute + LGZ fictive → guard bloque
--   S2 [auto] Retirer LGZ fictive → auto-unpack déclenche scène FOB
--   S3 [auto T+130] Vérifier FOB enregistré
--
-- Prérequis :
--   - UH-1H BLUE au sol, > 500 m de toute zone logistique existante
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--
-- @scenario  P2-FOB-PARA
-- @version   3.0 — 2026-06-30
-- @coverage  P2.1–P2.6
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[P2-FOB-PARA] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_P2FOBPARA_RUNNING then
    trigger.action.outText("[P2-FOB-PARA] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_P2FOBPARA_RUNNING = true
_SCN_P2FOBPARA_CLEANUP = nil

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG      = "[P2-FOB-PARA]"
local NAME     = "FOB auto-unpack depuis parachutage"
local FAKE_LGZ = "_p2_fake_lgz_"

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    groupId     = nil,
    timerHandle = nil,
    timerGen    = 0,
    transport   = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    log("[INSTR] " .. msg)
    trigger.action.outText(TAG .. "\n" .. msg, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end
local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_P2FOBPARA_RUNNING = false
    _SCN_P2FOBPARA_CLEANUP = nil
    log("cleanup done")
end

-- ── 9. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
    if S.timerHandle then
        pcall(timer.removeFunction, S.timerHandle)
        S.timerHandle = nil
    end
end

local function waitThen(delayS, callback)
    cancelTimer()
    local myGen = S.timerGen
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        callback()
    end, nil, timer.getTime() + delayS)
end

-- ── 10. Finalization ─────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    local total = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." ✅ [OK] "..NAME.." — "..S.passed.."/"..total.." PASS"
    else
        summary = TAG.." ❌ [KO] "..NAME.." — "..S.failed.." FAIL: "..
            table.concat(S.failReasons, " | ")
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_P2FOBPARA_RUNNING = false end
end

-- ── 12. Step runner ──────────────────────────────────────────────────────────
local steps = {}
local advanceStep

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then
        finalizeScenario()
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ S"..S.step.." ERREUR: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Spawn 3 FOB crates LANDED+fromParachute + LGZ fictive → guard doit bloquer
steps[1] = function()
    instruct(
        "Step 1/3 — GUARD TEST (P2.1–P2.3)\n"..
        "Spawn 3 crates FOB LANDED+fromParachute + LGZ fictive au centroïde.\n"..
        "Vérification auto que le guard bloque l'auto-unpack."
    )

    ctld_test.cleanup()

    if not S.transport then fail("P2.0", "aucun joueur BLUE") ; return end

    local cId   = S.transport:getCoalition()
    local pPos  = S.transport:getPoint()
    local hdg   = ctld.utils.getHeadingInRadians("p2", S.transport, true)

    -- Cleanup FOBs existants
    local fobMgr = CTLDFOBManager.getInstance()
    for _, fob in ipairs(fobMgr:getFOBsForCoalition(cId)) do
        pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(fob.name) end)
        fobMgr._fobs[fob.fobId] = nil
    end
    fobMgr._objectToFOB = {}

    -- Descriptor FOB
    local cm      = CTLDCrateManager.getInstance()
    local fobDesc = cm:findDescriptorByUnitType("FOB")
    check("P2.1", "FOB descriptor present", fobDesc ~= nil)
    if not fobDesc then fail("P2.1b", "FOB descriptor absent") ; return end

    -- Centroïde : 80 m devant l'hélico
    local cx = pPos.x + math.cos(hdg) * 80
    local cz = pPos.z + math.sin(hdg) * 80
    local cy = land.getHeight({ x = cx, y = cz })

    -- Spawn 3 FOB crates LANDED + fromParachute autour du centroïde (< 20 m)
    local spawned = 0
    for i = 1, 3 do
        local angle = (i - 1) * (2 * math.pi / 3)
        local nx = cx + math.cos(angle) * 8
        local nz = cz + math.sin(angle) * 8
        local ny = land.getHeight({ x = nx, y = nz })
        local c = cm:spawnCrate(fobDesc, { x = nx, y = ny, z = nz }, cId,
            "p2_script", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)
        if c then
            c.state         = CTLDCrate.STATE.LANDED
            c.fromParachute = true
            c.position      = { x = nx, y = ny, z = nz }
            spawned = spawned + 1
        end
    end
    check("P2.2", "3 crates FOB spawnées LANDED+fromParachute", spawned == 3, "spawned="..spawned)

    -- Enregistrer LGZ fictive AU centroïde (guard : trop proche = bloqué)
    local fakeRadius = ctld.gs("fobLogisticZoneRadius") or 150
    CTLDZoneManager.getInstance():registerFOBAsLogistic(FAKE_LGZ, { x = cx, y = cy, z = cz }, fakeRadius, cId)
    log("LGZ fictive '"..FAKE_LGZ.."' enregistrée au centroïde")

    local fobsBefore = #fobMgr:getFOBsForCoalition(cId)

    -- _checkAutoUnpack : doit être bloqué par la guard
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor and c.descriptor.unit == "FOB" then
            cm:_checkAutoUnpack(c)
            break
        end
    end

    local fobsAfter = #fobMgr:getFOBsForCoalition(cId)
    check("P2.3", "guard bloque FOB auto-unpack quand LGZ trop proche",
        fobsAfter == fobsBefore,
        "fobsBefore="..fobsBefore.." fobsAfter="..fobsAfter)

    log("Step 1 OK — retrait LGZ dans 1s pour step 2")
    waitThen(1, advanceStep)
end

-- S2 — Retirer la LGZ fictive → auto-unpack déclenche scène FOB
steps[2] = function()
    instruct(
        "Step 2/3 — HAPPY PATH (auto)\n"..
        "Retrait LGZ fictive → auto-unpack déclenche scène FOB.\n"..
        "Vérification du FOB dans 160s…"
    )

    local cId = S.transport and S.transport:getCoalition() or coalition.side.BLUE

    -- Retirer la LGZ fictive
    pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(FAKE_LGZ) end)
    log("LGZ fictive '"..FAKE_LGZ.."' retirée")

    local cm = CTLDCrateManager.getInstance()

    -- _checkAutoUnpack : guards passent maintenant → scène FOB se lance
    -- Temporarily clear ALL logistic zones so mission real LGZs (e.g. Batumi)
    -- don't block the guard (test is about the fake-LGZ guard, not real mission layout)
    local zm = CTLDZoneManager.getInstance()
    local _savedLGZs = zm._logisticZones
    zm._logisticZones = {}
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor and c.descriptor.unit == "FOB" then
            cm:_checkAutoUnpack(c)
            break
        end
    end
    zm._logisticZones = _savedLGZs

    log("Scène FOB lancée (async). Vérification dans 160s.")
    waitThen(160, advanceStep)
end

-- S3 — Vérifier FOB enregistré (~T+130)
steps[3] = function()
    instruct(
        "Step 3/3 — VÉRIFICATION FOB (auto)\n"..
        "Vérification auto que le FOB est enregistré dans CTLDFOBManager."
    )

    local cId = S.transport and S.transport:getCoalition() or coalition.side.BLUE
    local fobMgr = CTLDFOBManager.getInstance()
    local fobs   = fobMgr:getFOBsForCoalition(cId)

    check("P2.4", "au moins 1 FOB enregistré après auto-unpack parachute",
        #fobs >= 1, "count="..#fobs)

    if #fobs >= 1 then
        local fob = fobs[1]
        check("P2.5", "FOB isAlive()", fob:isAlive())
        local intPct = math.floor(fob:getIntegrityPercent() * 100 + 0.5)
        check("P2.6", "integrity = 100%", intPct == 100, "integrity="..intPct.."%")
        log(string.format("FOB '%s' @ (%.0f, %.0f) — %d%% intégrité",
            fob.name, fob.position.x, fob.position.z, intPct))
    end

    advanceStep()
end

-- ── 14. Start ────────────────────────────────────────────────────────────────
S.transport = (function()
    local ok, pm = pcall(CTLDPlayerManager.getInstance)
    if ok and pm and pm._players then
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() then return u end
        end
    end
    for _, grp in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        for _, unit in ipairs(grp:getUnits() or {}) do
            if unit and unit:isExist() and unit:getPlayerName() then return unit end
        end
    end
    return nil
end)()

if not S.transport then
    trigger.action.outText(TAG.." ABORT : aucun joueur BLUE. Occuper un slot avant injection.", 20)
    cleanup()
    return Witchcraft
end

_SCN_P2FOBPARA_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
