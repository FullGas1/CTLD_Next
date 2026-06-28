---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_jtac_vehicle_red.lua
-- Injectable test scenario — RED JTAC ground vehicle (SKP-11) vs BLUE enemy.
-- Mirrors: CTLDCrateManager:_spawnUnpacked → _dispatchPostSpawn → startLase
--
-- Pre-requisites:
--   - BLUE group "Sol_g-1" must exist (run diag/diag_spawn_sol_g1.lua to restore)
--   - Config: JTAC_dropEnabled = true (default)
--
-- Sequence:
--   T+0s  : cleanup ground JTACs; save enemy origin; spawn SKP-11 JTAC 100m from Sol_g-1
--   T+15s : VERIFY 1 — JTAC lasing Sol_g-1-1 (currentTarget set)
--   T+45s : destroy Sol_g-1 (guaranteed target loss)
--   T+80s : VERIFY 2 — target lost (currentTarget=nil)
--   T+85s : restore Sol_g-1 at original position
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG   = "[JTAC-VEH-RED]"
local START = os.date("%Y-%m-%d %H:%M:%S")

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local ENEMY_GROUP    = "Sol_g-1"
local SPAWN_OFFSET   = 100
local VEHICLE_WEIGHT = 1001.11    -- SKP-11 - JTAC, side=1 (RED)
local VEHICLE_CTY    = country.id.RUSSIA

-- ── HELPERS ───────────────────────────────────────────────────────────────────
local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end
local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 25)
    log(msg)
end
local function fail(msg)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. msg)
    error(msg)
end

-- ── MAIN ──────────────────────────────────────────────────────────────────────
report("==== START " .. START .. " ====")

local _result = ""
local _ok, _err = pcall(function()

    -- 0. cleanup existing ground JTACs
    local jmgr = CTLDJTACManager.get()
    local tmgr = CTLDTroopManager.getInstance()
    local cmgr = CTLDCrateManager.getInstance()

    local jtacKeys = {}
    for _, t in ipairs(tmgr._templates) do
        if t.hasJtac then jtacKeys[t._dbKey] = true end
    end

    local removed = 0
    local toKill = {}
    for gname, jtac in pairs(jmgr.jtacs) do
        if not jtac.isFlying then table.insert(toKill, gname) end
    end
    for _, gname in ipairs(toKill) do
        local dg = Group.getByName(gname)
        if dg and dg:isExist() then dg:destroy() end
        jmgr:killJTAC(gname, nil)
        removed = removed + 1
    end

    for coa = 1, 2 do
        local alive = {}
        for _, gname in ipairs(tmgr._droppedGroups[coa]) do
            local tmplKey = tmgr._droppedTemplates[gname]
            if jtacKeys[tmplKey] then
                local dg = Group.getByName(gname)
                if dg and dg:isExist() then dg:destroy() end
                tmgr._droppedTemplates[gname] = nil
                jmgr.jtacs[gname] = nil
                removed = removed + 1
            else
                table.insert(alive, gname)
            end
        end
        tmgr._droppedGroups[coa] = alive
    end

    for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        for _, grp in ipairs(coalition.getGroups(coa)) do
            local gname = grp:getName()
            if gname:find("^CTLD_UNP_") and grp:isExist() then
                grp:destroy()
                jmgr.jtacs[gname] = nil
                removed = removed + 1
            end
        end
    end

    report(string.format("Step 0: cleanup done (%d ground JTAC(s) removed)", removed))

    -- save enemy origin
    local enemyGrp = Group.getByName(ENEMY_GROUP)
    if not enemyGrp or not enemyGrp:isExist() then
        fail("enemy group not found: " .. ENEMY_GROUP .. " — run diag_spawn_sol_g1.lua first")
    end
    local enemyUnit = enemyGrp:getUnit(1)
    if not enemyUnit or not enemyUnit:isExist() then
        fail("no unit in group: " .. ENEMY_GROUP)
    end
    local epos            = enemyUnit:getPoint()
    local savedEnemyCntry = enemyUnit:getCountry()
    local savedEnemyType  = enemyUnit:getTypeName()
    local savedEnemyUName = enemyUnit:getName()
    local savedEnemyGName = enemyGrp:getName()
    local ox, oy, oz      = epos.x, epos.y, epos.z

    -- 1. find descriptor and spawn SKP-11
    local desc = cmgr:findDescriptorByWeight(VEHICLE_WEIGHT)
    if not desc then
        fail(string.format("no descriptor for weight=%.2f", VEHICLE_WEIGHT))
    end
    if not desc.isJTAC then
        fail(string.format("'%s' has no isJTAC=true", tostring(desc.desc)))
    end

    local gid      = ctld.utils.getNextUniqId()
    local uid      = ctld.utils.getNextUniqId()
    local gname    = string.format("CTLD_UNP_%d", uid)
    local spawnPos = { x = ox + SPAWN_OFFSET, y = oy, z = oz }

    local unitDef = ctld.utils.buildGroupUnitDef(desc, spawnPos, gname, gid, uid)
    local ok, err = ctld.utils.spawnFromDescriptor(desc, VEHICLE_CTY, unitDef)
    if not ok then
        fail(string.format("spawnFromDescriptor failed: %s", tostring(err)))
    end

    jmgr:startLase(gname)

    report(string.format("Step 1: '%s' (%s) spawned 100m from '%s' @ (%.0f,%.0f) — startLase called",
        desc.desc, desc.unit, ENEMY_GROUP, spawnPos.x, spawnPos.z))

    -- T+15s: VERIFY 1 — JTAC lasing enemy
    timer.scheduleFunction(function()
        local jtac = jmgr.jtacs[gname]
        if not jtac then
            report("VERIFY 1 FAIL — JTAC entry not found: " .. gname); return
        end
        if jtac.currentTarget then
            report(string.format("VERIFY 1 PASS — lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        else
            report(string.format("VERIFY 1 FAIL — no target | state=%s", tostring(jtac.state)))
        end
    end, nil, timer.getTime() + 15)

    -- T+45s: destroy enemy
    timer.scheduleFunction(function()
        local grp = Group.getByName(savedEnemyGName)
        if grp and grp:isExist() then grp:destroy() end
        report("Step 2: '" .. savedEnemyGName .. "' destroyed — JTAC should lose target")
    end, nil, timer.getTime() + 45)

    -- T+80s: VERIFY 2 — target lost
    timer.scheduleFunction(function()
        local jtac = jmgr.jtacs[gname]
        if not jtac then
            report("VERIFY 2 INFO — JTAC entry gone"); return
        end
        if not jtac.currentTarget then
            report(string.format("VERIFY 2 PASS — target lost confirmed | state=%s", tostring(jtac.state)))
        else
            report(string.format("VERIFY 2 FAIL — still lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        end
    end, nil, timer.getTime() + 80)

    -- T+85s: restore enemy
    timer.scheduleFunction(function()
        coalition.addGroup(savedEnemyCntry, Group.Category.GROUND, {
            id = ctld.utils.getNextUniqId(), name = savedEnemyGName, task = "Ground Nothing", start_time = 0,
            units = {{ id = ctld.utils.getNextUniqId(), name = savedEnemyUName, type = savedEnemyType,
                       x = ox, y = oz, heading = 0, skill = "Average", playerCanDrive = false }},
            route = { points = {{ x = ox, y = oz, type = "Turning Point",
                                   action = "Off Road", speed = 0, alt = oy }}},
        })
        report(string.format("Restore: '%s' back at (%.0f,%.0f)", savedEnemyGName, ox, oz))
    end, nil, timer.getTime() + 85)

    _result = string.format("started | '%s' | gname='%s' | enemy '%s' @ (%.0f,%.0f)",
        desc.desc, gname, ENEMY_GROUP, ox, oz)
end)

-- ── CLEANUP (debug always restored) ───────────────────────────────────────────
cfg.settings["debug"] = _saved_debug

if not _ok then
    return TAG .. " FAIL: " .. tostring(_err)
end
return TAG .. " " .. _result
