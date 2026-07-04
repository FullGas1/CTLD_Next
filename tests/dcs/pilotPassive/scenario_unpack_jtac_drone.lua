---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_unpack_jtac_drone.lua
-- CTLD — MQ-9 JTAC drone full lifecycle via crate spawn+unpack
--
-- Flow mirrors real player actions :
--   spawnCrate → crate on ground → unpackCrate → _spawnUnpacked → _dispatchPostSpawn → startLase
--
-- Cinématique (5 steps automatiques, injection unique) :
--   S1 [auto]       Cleanup + spawn MQ-9 crate + unpack → startLase via _dispatchPostSpawn
--   S2 [auto T+5]   Draw BLUE orbit circle
--   S3 [auto T+120] VERIFY 1 — drone idle on initial orbit ; spawn RED target
--   S4 [auto T+150] VERIFY 2 — drone lasing target ; draw RED circle
--   S5 [auto T+480] Destroy RED target
--   S6 [auto T+495] VERIFY 3 — target lost, drone returning to initial orbit
--   S7 [auto T+795] VERIFY 4 — drone still alive ; cleanup drone
--
-- Prérequis :
--   - Helicopter group "uh1" / unit "uh1-1" present and on ground near Batumi
--   - JTAC_dropEnabled = true, BLUE coalition
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--
-- @scenario  JTAC-DRONE
-- @version   3.0 — 2026-06-30
-- @coverage  Drone lifecycle F-xxx
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[JTAC-DRONE] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_JTACDRONE_RUNNING then
    trigger.action.outText("[JTAC-DRONE] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_JTACDRONE_RUNNING = true
_SCN_JTACDRONE_CLEANUP = nil

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG   = "[DRONE]"
local NAME  = "MQ-9 JTAC drone full lifecycle"

local HELO_NAME    = "uh1-1"
local MQ9_WEIGHT   = 1006.01
local CRATE_OFFSET = 5

local TARGET_GRP  = "JTAC_TEST_RED_TARGET"
local TARGET_UNIT = "JTAC_TEST_RED_TARGET-1"
local TARGET_TYPE = "Truck_URAL_4320_Cab"
local TARGET_CTY  = country.id.RUSSIA
local TARGET_X    = -361437
local TARGET_Z    = 618211
local TARGET_Y    = land.getHeight({ x = TARGET_X, y = TARGET_Z })

-- Monotonic mark index (préservé dans le scope do)
local mIdx = 9800
local function gidx() mIdx = mIdx + 1 ; return mIdx end

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
    -- Handles des timers de vérification (pour cancelTimer)
    verifyHandles = {},
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    log("[INSTR] " .. msg)
    trigger.action.outText(TAG .. "\n" .. msg, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function drawCircle(center, radius, r, g, b, label)
    trigger.action.circleToAll(-1, gidx(), center, radius,
        { r, g, b, 1.0 }, { r, g, b, 0.05 }, 1, false, label)
end

local function spawnRedTarget()
    local existing = Group.getByName(TARGET_GRP)
    if existing and existing:isExist() then existing:destroy() end
    coalition.addGroup(TARGET_CTY, Group.Category.GROUND, {
        id = ctld.utils.getNextUniqId(), name = TARGET_GRP, task = "Ground Nothing", start_time = 0,
        units = {{ id = ctld.utils.getNextUniqId(), name = TARGET_UNIT, type = TARGET_TYPE,
                   x = TARGET_X, y = TARGET_Z, heading = 0, skill = "Average", playerCanDrive = false }},
        route = { points = {{ x = TARGET_X, y = TARGET_Z,
                               type = "Turning Point", action = "Off Road", speed = 0, alt = TARGET_Y }}},
    })
end

local function destroyRedTarget()
    local grp = Group.getByName(TARGET_GRP)
    if grp and grp:isExist() then grp:destroy() end
end

local function getFlyingJtac()
    local jmgr = CTLDJTACManager.get()
    for gname, j in pairs(jmgr.jtacs) do
        if j.isFlying then return gname, j end
    end
    return nil, nil
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then
        pcall(timer.removeFunction, S.timerHandle)
        S.timerHandle = nil
    end
    for _, h in ipairs(S.verifyHandles) do
        pcall(timer.removeFunction, h)
    end
    S.verifyHandles = {}
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_JTACDRONE_RUNNING = false
    _SCN_JTACDRONE_CLEANUP = nil
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

-- Planifier un timer de vérification indépendant (non annulé par cancelTimer)
local function scheduleVerify(delayS, fn)
    local h = timer.scheduleFunction(function()
        fn()
        return nil
    end, nil, timer.getTime() + delayS)
    table.insert(S.verifyHandles, h)
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_JTACDRONE_RUNNING = false end
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

-- S1 — Cleanup + spawn MQ-9 crate + unpack → startLase (auto, T+0)
steps[1] = function()
    instruct(
        "Step 1/2 — SPAWN + UNPACK DRONE MQ-9 (auto)\n"..
        "Cleanup + spawn crate + unpack → startLase.\n"..
        "Les vérifications auto s'enchainent sur 795s…"
    )

    local jmgr = CTLDJTACManager.get()
    local cmgr = CTLDCrateManager.getInstance()

    -- Cleanup : détruire les JTAC existants
    local toKill = {}
    for gname, _ in pairs(jmgr.jtacs) do table.insert(toKill, gname) end
    for _, gname in ipairs(toKill) do
        local dg = Group.getByName(gname)
        if dg and dg:isExist() then dg:destroy() end
        jmgr:killJTAC(gname, nil)
    end

    for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        for _, grp in ipairs(coalition.getGroups(coa)) do
            local gname = grp:getName()
            if (gname:find("^CTLD_UNP_") or gname:find("^CTLD_AIR_")) and grp:isExist() then
                grp:destroy() ; jmgr.jtacs[gname] = nil
            end
        end
    end

    destroyRedTarget()
    log("Step 0: cleanup done")

    -- 1. Spawn crate MQ-9 devant l'hélico
    local heloUnit = S.transport
    if not heloUnit or not heloUnit:isExist() then
        fail("DRONE.1", "helo unit not found (S.transport nil or dead)")
        return
    end

    local desc = cmgr:findDescriptorByWeight(MQ9_WEIGHT)
    if not desc then
        fail("DRONE.2", "MQ-9 descriptor not found (weight="..MQ9_WEIGHT..")")
        return
    end

    local hpos = heloUnit:getPoint()
    local hdg  = ctld.utils.getHeadingInRadians("scenario_unpack_jtac_drone", heloUnit, true)
    local cratePos = {
        x = hpos.x + CRATE_OFFSET * math.cos(hdg),
        y = hpos.y,
        z = hpos.z + CRATE_OFFSET * math.sin(hdg),
    }

    local crate = cmgr:spawnCrate(desc, cratePos, coalition.side.BLUE, HELO_NAME,
        CTLDCrate.SPAWN_METHOD.MENU_CTLD, country.id.USA)
    if not crate then
        fail("DRONE.3", "spawnCrate failed for MQ-9")
        return
    end

    pass("DRONE.1", string.format("MQ-9 crate '%s' spawned at (%.0f,%.0f)", crate.crateName, cratePos.x, cratePos.z))

    -- 2. Unpack crate + spawn drone
    local spawnInfo = ctld.utils.getSpawnObjectPositions(heloUnit, 1, 50)
    local spawnPos  = spawnInfo and spawnInfo.positions and spawnInfo.positions[1]
    if not spawnPos then
        fail("DRONE.4", "getSpawnObjectPositions failed")
        return
    end

    cmgr:unpackCrate(crate.crateName, heloUnit)
    cmgr:_spawnUnpacked(desc, spawnPos, coalition.side.BLUE, country.id.USA)
    pass("DRONE.2", string.format("crate unpacked + MQ-9 spawned at (%.0f,%.0f) → startLase via _dispatchPostSpawn",
        spawnPos.x, spawnPos.z))

    -- Planifier les vérifications différées (indépendantes de cancelTimer)
    scheduleVerify(5, function()
        local gname, jtac = getFlyingJtac()
        if not jtac then log("T+5s: WARNING — no flying JTAC found yet") ; return end

        local op = jtac.orbitParams
        local rNoLase = (op and op.orbitRadiusNoLase) or ctld.gs("jtacDroneRadius") or 1000

        if jtac.initialPosition then
            drawCircle(jtac.initialPosition, rNoLase, 0.2, 0.5, 1.0,
                string.format("INITIAL ORBIT %s r=%dm", gname, rNoLase))
        end

        log(string.format("T+5s: %s | state=%s | rNoLase=%dm | rOnLase=%dm",
            gname, tostring(jtac.state), rNoLase,
            (op and op.orbitRadiusOnLase) or ctld.gs("jtacDroneRadius") or 1000))
    end)

    scheduleVerify(120, function()
        local gname, jtac = getFlyingJtac()
        if not jtac then log("VERIFY 1 FAIL — no flying JTAC") ; fail("DRONE.V1", "no flying JTAC at T+120") ; return end

        if not jtac.currentTarget then
            pass("DRONE.V1", string.format("drone idle on initial orbit | state=%s", tostring(jtac.state)))
        else
            log(string.format("VERIFY 1 WARN — drone already lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        end

        spawnRedTarget()
        log(string.format("Step 3: RED target '%s' spawned at (%.0f,%.0f,h=%.0f)",
            TARGET_TYPE, TARGET_X, TARGET_Z, TARGET_Y))
    end)

    scheduleVerify(150, function()
        local gname, jtac = getFlyingJtac()
        if not jtac then fail("DRONE.V2", "no flying JTAC at T+150") ; return end

        if jtac.currentTarget then
            local op = jtac.orbitParams
            local rOnLase = (op and op.orbitRadiusOnLase) or ctld.gs("jtacDroneRadius") or 1000
            pass("DRONE.V2", string.format("lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))

            local tu = Unit.getByName(jtac.currentTarget.unitName)
            if tu and tu:isExist() then
                drawCircle(tu:getPoint(), rOnLase, 1.0, 0.1, 0.1,
                    string.format("TARGET ORBIT r=%dm — %s", rOnLase, jtac.currentTarget.unitName))
            end
        else
            fail("DRONE.V2", string.format("no target at T+150 | state=%s", tostring(jtac.state)))
        end
    end)

    scheduleVerify(480, function()
        destroyRedTarget()
        log("Step 4: RED target destroyed — expect target lost + drone returns to initial orbit")
    end)

    scheduleVerify(495, function()
        local gname, jtac = getFlyingJtac()
        if not jtac then log("VERIFY 3 INFO — JTAC gone") ; return end

        if not jtac.currentTarget then
            pass("DRONE.V3", string.format("target lost | state=%s — drone heading to initial orbit",
                tostring(jtac.state)))
        else
            fail("DRONE.V3", string.format("still lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        end
    end)

    scheduleVerify(795, function()
        local gname, jtac = getFlyingJtac()
        if not jtac then log("VERIFY 4 INFO — JTAC gone") ; return end

        local g = Group.getByName(gname)
        local u = g and g:getUnit(1)
        local dpos = u and u:getPoint()

        if not jtac.currentTarget then
            pass("DRONE.V4", string.format("drone idle | state=%s | pos=(%.0f,%.0f)",
                tostring(jtac.state), dpos and dpos.x or 0, dpos and dpos.z or 0))
            if dpos then
                trigger.action.markToAll(gidx(),
                    string.format("DRONE T+795s | state=%s", jtac.state), dpos, false, "")
            end
        else
            fail("DRONE.V4", string.format("still lasing '%s'", jtac.currentTarget.unitName))
        end

        -- Cleanup drone
        if g and g:isExist() then g:destroy() end
        jmgr:killJTAC(gname, nil)
        log("Step 5: drone cleaned up")

        -- Finalisation après la dernière vérification
        advanceStep()
    end)

    -- Passer au step suivant après avoir planifié tous les timers de vérification
    waitThen(1, advanceStep)
end

-- S2 — Attendre la fin des vérifications (step de liaison)
steps[2] = function()
    instruct(
        "Step 2/2 — VÉRIFICATIONS EN COURS…\n"..
        "Les vérifications s'exécutent automatiquement sur 795s.\n"..
        "T+120s : VERIFY 1 (idle + spawn RED)\n"..
        "T+150s : VERIFY 2 (lasing target)\n"..
        "T+480s : Destroy RED target\n"..
        "T+495s : VERIFY 3 (target lost)\n"..
        "T+795s : VERIFY 4 (idle final + cleanup) → résultat final"
    )
    -- Ce step ne s'avance pas seul : advanceStep() est appelé depuis scheduleVerify(795)
    -- (voir la vérification T+795 dans S1)
end

-- ── 14. Start ────────────────────────────────────────────────────────────────
-- Transport non requis pour ce scénario, mais tentative de lookup pour les logs
S.transport = (function()
    local ok, pm = pcall(CTLDPlayerManager.getInstance)
    if ok and pm and pm._players then
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() then return u end
        end
    end
    -- Fallback : helo fixe
    return Unit.getByName(HELO_NAME)
end)()

_SCN_JTACDRONE_CLEANUP = cleanup

local transportStr = S.transport and S.transport:getName() or HELO_NAME
log("=== START: "..NAME.." | helo="..transportStr.." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — lifecycle 795s | helo="..transportStr, 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
