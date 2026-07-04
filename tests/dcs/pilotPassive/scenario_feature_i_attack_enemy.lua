---@diagnostic disable
-- =============================================================================
-- scenario_feature_i_attack_enemy.lua
-- Feature I — Post-spawn task: "AttackNearestEnemyOnLos"
--
-- Verifies that a spawned troop group is ordered to advance toward the nearest
-- RED enemy unit in LOS when specificParams = { task = "AttackNearestEnemyOnLos" }.
--
-- Protocol:
--   Step 1 — Spawn RED enemy 300 m from player (open terrain → LOS guaranteed),
--             spawn BLUE group at player position, call _assignPostSpawnTask
--   Step 2 — (inject 3s later) Verify CTLD.log contains assignment confirmation
--   Step 3 — Cleanup (destroy enemy + BLUE group)
--
-- Pre-requisites:
--   - BLUE player slot occupied (any aircraft), on ground level (no occlusion)
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait before this scenario)
--   - recette/enable_debug.lua injected before this scenario
--   - Mission terrain must be flat near player (no ridge blocking LOS at 300 m)
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FI-ATK] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[FI-ATK]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_FI_ATK_STEP"

local BLUE_GRP  = "FI_ATK_BlueGroup"
local RED_GRP   = "FI_ATK_RedEnemy"
local ENEMY_DIST = 100   -- metres east of spawn — close enough for infantry to engage quickly

local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end
local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 30)
    log(msg)
end
local function pass(msg)  report("[PASS] " .. msg) end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (details and (" | " .. details) or "")) end
end

-- ── CLEANUP ───────────────────────────────────────────────────────────────────
local function cleanup()
    for _, name in ipairs({ BLUE_GRP, RED_GRP }) do
        local grp = Group.getByName(name)
        if grp and grp:isExist() then grp:destroy() end
    end
    -- Remove F10 draw marks
    for i = 98801, 98901 do pcall(function() trigger.action.removeMark(i) end) end
    _G["_FI_ATK_ENEMY_PT"]  = nil
    _G["_FI_ATK_DIST_ORIG"] = nil
    log("cleanup done")
end

-- ── PLAYER RESOLUTION ─────────────────────────────────────────────────────────
local playerUnit = nil
for attempt = 1, 5 do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 and units[1]:isExist() then
        playerUnit = units[1]; break
    end
    local t = os.clock() + 0.5; while os.clock() < t do end
end
if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
    return TAG .. " ABORT: no BLUE player"
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

if step == 1 then pcall(function()
    ctld.utils.closeLog()
    local f = io.open((cfg.settings["ctldLogPath"] or "") .. "CTLD.log", "w")
    if f then f:write("[" .. START .. "] === LOG RESET ===\n"); f:close() end
    ctld.utils.reopenLogAppend()
end) end

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Spawn RED enemy + BLUE group, call _assignPostSpawnTask
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then
    cleanup()

    local pPos = playerUnit:getPoint()
    -- Offset 50 m south to avoid airbase concrete (same fix as scenario 1)
    local spawnPt = { x = pPos.x, y = 0, z = pPos.z - 50 }
    spawnPt.y = land.getHeight({ x = spawnPt.x, y = spawnPt.z })
    -- Enemy 300 m east of spawn
    local enemyPt = { x = spawnPt.x + ENEMY_DIST, y = 0, z = spawnPt.z }
    enemyPt.y = land.getHeight({ x = enemyPt.x, y = enemyPt.z })

    -- LOS pre-check
    local offsetA = { x = spawnPt.x, y = spawnPt.y + 2, z = spawnPt.z }
    local offsetB = { x = enemyPt.x, y = enemyPt.y + 2, z = enemyPt.z }
    local hasLOS  = land.isVisible(offsetA, offsetB)
    log("LOS pre-check (spawn→enemy " .. ENEMY_DIST .. "m east): " .. tostring(hasLOS))

    local blueCountry = playerUnit:getCountry()
    local redCountry  = country.id.RUSSIA

    -- Spawn RED enemy
    -- RED: unarmed Hummer in RED coalition — stationary target, won't shoot
    local redGrp = coalition.addGroup(redCountry, Group.Category.GROUND, {
        name  = RED_GRP, task = "Ground Nothing",
        units = {{ name = RED_GRP .. "_u1", type = "Hummer",
                   x = enemyPt.x, y = enemyPt.z, heading = 0, skill = "High",
                   playerCanDrive = false, unitId = math.random(91000, 91999) }},
    })
    check("FI-ATK.1.1", "RED Hummer spawned", redGrp ~= nil)

    -- BLUE: infantry soldier — approaches and fires on the Hummer
    local blueGrp = coalition.addGroup(blueCountry, Group.Category.GROUND, {
        name       = BLUE_GRP,
        task       = "Ground Nothing",
        start_time = 0,
        groupId    = math.random(93000, 93999),
        units = {{ name = BLUE_GRP .. "_u1", type = "Soldier M4",
                   x = spawnPt.x, y = spawnPt.z, heading = 0, skill = "High",
                   unitId = math.random(92000, 92999) }},  -- no playerCanDrive on infantry
    })
    check("FI-ATK.1.2", "BLUE group spawned", blueGrp ~= nil)

    -- Store positions for step 2 comparison
    _G["_FI_ATK_ENEMY_PT"]  = enemyPt
    _G["_FI_ATK_SPAWN_PT"]  = { x = spawnPt.x, y = spawnPt.y, z = spawnPt.z }
    _G["_FI_ATK_DIST_ORIG"] = ctld.utils.getDistance("FI-ATK.1", spawnPt, enemyPt)

    -- ── Visual draws on F10 map ─────────────────────────────────────────────
    -- Enemy marker: red cross (two lines)
    local r = 40
    trigger.action.lineToAll(-1, 98801, { x=enemyPt.x-r, y=enemyPt.y, z=enemyPt.z   },
                                         { x=enemyPt.x+r, y=enemyPt.y, z=enemyPt.z   },
                             { 1, 0, 0, 0.9 }, 3)
    trigger.action.lineToAll(-1, 98802, { x=enemyPt.x,   y=enemyPt.y, z=enemyPt.z-r },
                                         { x=enemyPt.x,   y=enemyPt.y, z=enemyPt.z+r },
                             { 1, 0, 0, 0.9 }, 3)
    -- Enemy circle r=80m
    local steps = 24
    for i = 0, steps-1 do
        local a1 = i       * (2*math.pi/steps)
        local a2 = (i+1)   * (2*math.pi/steps)
        trigger.action.lineToAll(-1, 98810+i,
            { x=enemyPt.x+r*2*math.cos(a1), y=enemyPt.y, z=enemyPt.z+r*2*math.sin(a1) },
            { x=enemyPt.x+r*2*math.cos(a2), y=enemyPt.y, z=enemyPt.z+r*2*math.sin(a2) },
            { 1, 0, 0, 0.7 }, 2)
    end
    -- Label
    trigger.action.textToAll(-1, 98899, enemyPt, { 1, 0, 0, 1 }, { 0,0,0,0 }, 14, true, "Enemy")
    -- LOS line (yellow): spawn → enemy
    trigger.action.lineToAll(-1, 98900, spawnPt, enemyPt, { 1, 1, 0, 0.7 }, 1)
    -- BLUE spawn marker (blue dot)
    trigger.action.textToAll(-1, 98901, spawnPt, { 0, 0.5, 1, 1 }, { 0,0,0,0 }, 12, true, "BLUE spawn")
    log("F10 draw: enemy cross+circle (red), LOS line (yellow)")

    -- Schedule zone-entry detection (BLUE approaching enemy within 60 m)
    timer.scheduleFunction(function(arg)
        local bg = Group.getByName(arg.blueGrp)
        if not bg or not bg:isExist() then return end
        local u = bg:getUnit(1)
        if not (u and u:isExist()) then return end
        local dist = ctld.utils.getDistance("FI-ATK.enter", u:getPoint(), arg.enemyPt)
        if dist < 60 then
            trigger.action.outText("[FI-ATK] BLUE reached enemy area (dist=" ..
                string.format("%.0f", dist) .. "m)", 20)
            ctld.utils.log("INFO", "[FI-ATK] BLUE reached enemy area dist=%.0f", dist)
        else
            return timer.getTime() + 2
        end
    end, { blueGrp = BLUE_GRP, enemyPt = enemyPt }, timer.getTime() + 3)

    -- Trigger post-spawn task
    CTLDTroopManager.getInstance():_assignPostSpawnTask(
        BLUE_GRP, spawnPt, coalition.side.BLUE, { task = "AttackNearestEnemyOnLos" })
    log("_assignPostSpawnTask called — task will execute in 2s")

    pass("Step 1 OK — re-inject in 8s+ for Step 2")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Verify movement toward enemy
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then
    -- BLUE group still alive
    local grp = Group.getByName(BLUE_GRP)
    check("FI-ATK.2.1", "BLUE group still alive", grp ~= nil and grp:isExist())

    -- Unit has moved from its spawn position (getVelocity unreliable for infantry)
    local unit1   = grp and grp:getUnit(1)
    local uPt     = unit1 and unit1:getPoint()
    local sPt     = _G["_FI_ATK_SPAWN_PT"]
    local ePt     = _G["_FI_ATK_ENEMY_PT"]
    local dOrig   = _G["_FI_ATK_DIST_ORIG"] or math.huge

    if uPt and sPt then
        local moved = ctld.utils.getDistance("FI-ATK.2.2", uPt, sPt)
        log("BLUE moved from spawn: " .. string.format("%.1f", moved) .. " m")
        check("FI-ATK.2.2", "BLUE unit moved from spawn position (> 1 m)",
            moved > 1, "moved=" .. string.format("%.1f", moved) .. "m")
    end

    if uPt and ePt then
        local dNow = ctld.utils.getDistance("FI-ATK.2.3", uPt, ePt)
        log("dist to enemy: orig=" .. string.format("%.1f", dOrig) ..
            " now=" .. string.format("%.1f", dNow))
        check("FI-ATK.2.3", "BLUE unit closer to enemy than at spawn",
            dNow < dOrig,
            "orig=" .. string.format("%.1f", dOrig) ..
            " now=" .. string.format("%.1f", dNow))
    end

    pass("Step 2 OK — AttackNearestEnemyOnLos confirmed. Re-inject for cleanup.")
    _G[STEP_N] = 99
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP FINAL — Cleanup + Summary
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then
    cleanup()
    report("═══════════════════════════════════════")
    report("FI-ATK — ALL STEPS COMPLETE")
    report("═══════════════════════════════════════")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"
else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
