---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_troop_jtac.lua
-- Injectable test scenario — ground JTAC troop auto-lase cycle.
--
-- Pre-requisites:
--   - Enemy group "Sol_g-2" must exist (unit "Sol_g-2-1")
--   - A loadableGroup with jtac >= 1 must be configured (default: "JTAC Group")
--
-- Sequence:
--   T+0s  : cleanup ground JTAC groups; spawn JTAC troop 100m from enemy → startLase
--   T+15s : VERIFY 1 — JTAC lasing enemy (currentTarget set)
--   T+45s : move enemy 30km north (LOS lost)
--   T+80s : VERIFY 2 — target lost (currentTarget=nil)
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG   = "[JTAC-TROOP]"
local START = os.date("%Y-%m-%d %H:%M:%S")

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local ENEMY_GROUP  = "Sol_g-2"
local SPAWN_OFFSET = 100
local OFFSET_FAR   = 30000

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

local function moveGroupByDx(groupName, dx)
    local grp = Group.getByName(groupName)
    if not grp or not grp:isExist() then return nil end
    local u = grp:getUnit(1)
    if not u or not u:isExist() then return nil end
    local pos   = u:getPoint()
    local cntry = u:getCountry()
    local utype = u:getTypeName()
    local uname = u:getName()
    local gname = grp:getName()
    grp:destroy()
    local nx = pos.x + dx
    coalition.addGroup(cntry, Group.Category.GROUND, {
        id = ctld.utils.getNextUniqId(), name = gname, task = "Ground Nothing", start_time = 0,
        units = {{ id = ctld.utils.getNextUniqId(), name = uname, type = utype,
                   x = nx, y = pos.z, heading = 0, skill = "Average", playerCanDrive = false }},
        route = { points = {{ x = nx, y = pos.z, type = "Turning Point",
                               action = "Off Road", speed = 0, alt = pos.y }}},
    })
    return pos
end

-- ── MAIN ──────────────────────────────────────────────────────────────────────
report("==== START " .. START .. " ====")

local _result = ""
local _ok, _err = pcall(function()

    -- 0. cleanup existing ground JTACs
    local jmgr = CTLDJTACManager.get()
    local tmgr = CTLDTroopManager.getInstance()

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

    report(string.format("Step 0: cleanup done (%d ground JTAC group(s) removed)", removed))

    -- 1. find JTAC template
    local jtacTmpl = nil
    for _, t in ipairs(tmgr._templates) do
        if t.hasJtac then jtacTmpl = t; break end
    end
    if not jtacTmpl then
        fail("no loadableGroup with hasJtac=true — add jtac>=1 to loadableGroups config")
    end

    -- 2. get enemy position and spawn JTAC troop nearby
    local enemyGrp = Group.getByName(ENEMY_GROUP)
    if not enemyGrp or not enemyGrp:isExist() then
        fail("enemy group not found: " .. ENEMY_GROUP)
    end
    local enemyUnit = enemyGrp:getUnit(1)
    if not enemyUnit or not enemyUnit:isExist() then
        fail("no unit in group: " .. ENEMY_GROUP)
    end
    local epos = enemyUnit:getPoint()

    local spawnX = epos.x + SPAWN_OFFSET
    local spawnZ = epos.z

    local dcsGroup = CTLDObjectRegistry.spawnObject(
        jtacTmpl._dbKey,
        coalition.side.BLUE,
        country.id.USA,
        spawnX, spawnZ, 0
    )
    if not dcsGroup then
        fail("CTLDObjectRegistry.spawnObject failed for key: " .. tostring(jtacTmpl._dbKey))
    end

    local jtacGroupName = dcsGroup:getName()

    table.insert(tmgr._droppedGroups[coalition.side.BLUE], jtacGroupName)
    tmgr._droppedTemplates[jtacGroupName] = jtacTmpl._dbKey

    jmgr:startLase(jtacGroupName)

    report(string.format(
        "Step 1: JTAC troop '%s' spawned 100m from '%s' @ (%.0f,%.0f) — startLase called",
        jtacGroupName, ENEMY_GROUP, spawnX, spawnZ))

    -- T+15s: VERIFY 1 — JTAC lasing enemy
    timer.scheduleFunction(function()
        local jtac = CTLDJTACManager.get().jtacs[jtacGroupName]
        if not jtac then
            report("VERIFY 1 FAIL — JTAC entry not found in manager"); return
        end
        if jtac.currentTarget then
            report(string.format("VERIFY 1 PASS — lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        else
            report(string.format("VERIFY 1 FAIL — no target yet | state=%s", tostring(jtac.state)))
        end
    end, nil, timer.getTime() + 15)

    -- T+45s: move enemy 30km north
    timer.scheduleFunction(function()
        moveGroupByDx(ENEMY_GROUP, OFFSET_FAR)
        report("Step 3: '" .. ENEMY_GROUP .. "' moved 30km north — expect target lost")
    end, nil, timer.getTime() + 45)

    -- T+80s: VERIFY 2 — target lost
    timer.scheduleFunction(function()
        local jtac = CTLDJTACManager.get().jtacs[jtacGroupName]
        if not jtac then
            report("VERIFY 2 INFO — JTAC entry gone (soldier dead?)"); return
        end
        if not jtac.currentTarget then
            report(string.format("VERIFY 2 PASS — target lost confirmed | state=%s", tostring(jtac.state)))
        else
            report(string.format("VERIFY 2 FAIL — still lasing '%s' | state=%s",
                jtac.currentTarget.unitName, tostring(jtac.state)))
        end
    end, nil, timer.getTime() + 80)

    _result = string.format("started | tmpl='%s' | jtac='%s' | enemy @ (%.0f,%.0f)",
        jtacTmpl.name, jtacGroupName, epos.x, epos.z)
end)

-- ── CLEANUP (debug always restored) ───────────────────────────────────────────
cfg.settings["debug"] = _saved_debug

if not _ok then
    return TAG .. " FAIL: " .. tostring(_err)
end
return TAG .. " " .. _result
