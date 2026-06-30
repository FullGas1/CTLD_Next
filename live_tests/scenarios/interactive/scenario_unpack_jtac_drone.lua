---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_unpack_jtac_drone.lua
-- Injectable test scenario — MQ-9 JTAC drone full lifecycle via crate spawn+unpack.
--
-- Flow mirrors real player actions:
--   spawnCrate → crate on ground → unpackCrate → _spawnUnpacked → _dispatchPostSpawn → startLase
--
-- Pre-requisites:
--   - Helicopter group "uh1" / unit "uh1-1" present and on ground near Batumi
--   - JTAC_dropEnabled = true, BLUE coalition
--
-- Timings (from injection T=0):
--   T+0s   : cleanup + spawn MQ-9 crate + unpack → startLase via _dispatchPostSpawn
--   T+5s   : draw BLUE orbit circle
--   T+120s : VERIFY 1 — drone idle on initial orbit; spawn RED target
--   T+150s : VERIFY 2 — drone lasing target; draw RED circle
--   T+480s : destroy RED target
--   T+495s : VERIFY 3 — target lost, drone returning to initial orbit
--   T+795s : VERIFY 4 — drone still alive; cleanup drone
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────

-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[JTAC-DRONE] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG   = "[DRONE]"
local START = os.date("%Y-%m-%d %H:%M:%S")

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local HELO_NAME    = "uh1-1"
local MQ9_WEIGHT   = 1006.01
local CRATE_OFFSET = 5

local TARGET_GRP   = "JTAC_TEST_RED_TARGET"
local TARGET_UNIT  = "JTAC_TEST_RED_TARGET-1"
local TARGET_TYPE  = "Truck_URAL_4320_Cab"
local TARGET_CTY   = country.id.RUSSIA
local TARGET_X     = -361437
local TARGET_Z     = 618211
local TARGET_Y     = land.getHeight({ x = TARGET_X, y = TARGET_Z })

-- Monotonic mark index (preserved across injections)
if mIdx == nil then mIdx = 9800 end
local function gidx() mIdx = mIdx + 1; return mIdx end

-- ── HELPERS ───────────────────────────────────────────────────────────────────
local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end
local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 30)
    log(msg)
end
local function fail(msg)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. msg)
    error(msg)
end

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

-- ── MAIN ──────────────────────────────────────────────────────────────────────
report("==== START " .. START .. " ====")

local _result = ""
local _ok, _err = pcall(function()

    local jmgr = CTLDJTACManager.get()
    local cmgr = CTLDCrateManager.getInstance()

    -- 0. cleanup
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
                grp:destroy(); jmgr.jtacs[gname] = nil
            end
        end
    end

    destroyRedTarget()
    report("Step 0: cleanup done")

    -- 1. spawn MQ-9 crate in front of helo
    local heloUnit = Unit.getByName(HELO_NAME)
    if not heloUnit or not heloUnit:isExist() then
        fail("helo unit not found: " .. HELO_NAME)
    end

    local desc = cmgr:findDescriptorByWeight(MQ9_WEIGHT)
    if not desc then
        fail("MQ-9 descriptor not found (weight=" .. MQ9_WEIGHT .. ")")
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
    if not crate then fail("spawnCrate failed for MQ-9") end

    report(string.format("Step 1: MQ-9 crate '%s' spawned at (%.0f,%.0f)", crate.crateName, cratePos.x, cratePos.z))

    -- 2. unpack crate + spawn drone
    local spawnInfo = ctld.utils.getSpawnObjectPositions(heloUnit, 1, 50)
    local spawnPos  = spawnInfo and spawnInfo.positions and spawnInfo.positions[1]
    if not spawnPos then
        fail("getSpawnObjectPositions failed")
    end

    cmgr:unpackCrate(crate.crateName, heloUnit)
    cmgr:_spawnUnpacked(desc, spawnPos, coalition.side.BLUE, country.id.USA)
    report(string.format("Step 2: crate unpacked + MQ-9 spawned at (%.0f,%.0f) → startLase via _dispatchPostSpawn",
        spawnPos.x, spawnPos.z))

    -- T+5s: draw BLUE initial orbit circle
    timer.scheduleFunction(function()
        local gname, jtac = getFlyingJtac()
        if not jtac then report("T+5s: WARNING — no flying JTAC found yet"); return end

        local op = jtac.orbitParams
        local rNoLase = (op and op.orbitRadiusNoLase) or ctld.gs("jtacDroneRadius") or 1000

        if jtac.initialPosition then
            drawCircle(jtac.initialPosition, rNoLase, 0.2, 0.5, 1.0,
                string.format("INITIAL ORBIT %s r=%dm", gname, rNoLase))
        end

        report(string.format("T+5s: %s | state=%s | rNoLase=%dm | rOnLase=%dm",
            gname, tostring(jtac.state), rNoLase,
            (op and op.orbitRadiusOnLase) or ctld.gs("jtacDroneRadius") or 1000))
    end, nil, timer.getTime() + 5)

    -- T+120s: VERIFY 1 + spawn RED target
    timer.scheduleFunction(function()
        local gname, jtac = getFlyingJtac()
        if not jtac then report("VERIFY 1 FAIL — no flying JTAC"); return end

        if not jtac.currentTarget then
            report(string.format("VERIFY 1 PASS — drone idle on initial orbit | state=%s", tostring(jtac.state)))
        else
            report(string.format("VERIFY 1 WARN — drone already lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        end

        spawnRedTarget()
        report(string.format("Step 3: RED target '%s' spawned at (%.0f,%.0f,h=%.0f)",
            TARGET_TYPE, TARGET_X, TARGET_Z, TARGET_Y))
    end, nil, timer.getTime() + 120)

    -- T+150s: VERIFY 2 — drone lasing target
    timer.scheduleFunction(function()
        local gname, jtac = getFlyingJtac()
        if not jtac then report("VERIFY 2 FAIL — no flying JTAC"); return end

        if jtac.currentTarget then
            local op = jtac.orbitParams
            local rOnLase = (op and op.orbitRadiusOnLase) or ctld.gs("jtacDroneRadius") or 1000
            report(string.format("VERIFY 2 PASS — lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))

            local tu = Unit.getByName(jtac.currentTarget.unitName)
            if tu and tu:isExist() then
                drawCircle(tu:getPoint(), rOnLase, 1.0, 0.1, 0.1,
                    string.format("TARGET ORBIT r=%dm — %s", rOnLase, jtac.currentTarget.unitName))
            end
        else
            report(string.format("VERIFY 2 FAIL — no target | state=%s", tostring(jtac.state)))
        end
    end, nil, timer.getTime() + 150)

    -- T+480s: destroy RED target
    timer.scheduleFunction(function()
        destroyRedTarget()
        report("Step 4: RED target destroyed — expect target lost + drone returns to initial orbit")
    end, nil, timer.getTime() + 480)

    -- T+495s: VERIFY 3 — target lost
    timer.scheduleFunction(function()
        local gname, jtac = getFlyingJtac()
        if not jtac then report("VERIFY 3 INFO — JTAC gone"); return end

        if not jtac.currentTarget then
            report(string.format("VERIFY 3 PASS — target lost | state=%s — drone heading to initial orbit",
                tostring(jtac.state)))
        else
            report(string.format("VERIFY 3 FAIL — still lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        end
    end, nil, timer.getTime() + 495)

    -- T+795s: VERIFY 4 — drone back on initial orbit
    timer.scheduleFunction(function()
        local gname, jtac = getFlyingJtac()
        if not jtac then report("VERIFY 4 INFO — JTAC gone"); return end

        local g = Group.getByName(gname)
        local u = g and g:getUnit(1)
        local dpos = u and u:getPoint()

        if not jtac.currentTarget then
            report(string.format("VERIFY 4 PASS — drone idle | state=%s | pos=(%.0f,%.0f)",
                tostring(jtac.state), dpos and dpos.x or 0, dpos and dpos.z or 0))
            if dpos then
                trigger.action.markToAll(gidx(),
                    string.format("DRONE T+795s | state=%s", jtac.state), dpos, false, "")
            end
        else
            report(string.format("VERIFY 4 FAIL — still lasing '%s'", jtac.currentTarget.unitName))
        end

        -- cleanup drone
        if g and g:isExist() then g:destroy() end
        jmgr:killJTAC(gname, nil)
        report("Step 5: drone cleaned up")
    end, nil, timer.getTime() + 795)

    _result = string.format("started | crate='%s' | helo='%s' @ (%.0f,%.0f)",
        crate.crateName, HELO_NAME, hpos.x, hpos.z)
end)

-- ── CLEANUP (debug always restored) ───────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

if not _ok then
    return TAG .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ DONE", 20, true)
return TAG .. " " .. _result
