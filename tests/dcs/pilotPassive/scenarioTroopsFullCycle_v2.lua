---@diagnostic disable
-- =============================================================================
-- SCENARIO: scenarioTroopsFullCycle_v2.lua
-- Full troop lifecycle — CTLDTroopGroup (inf=4, jtac=2), 8-step state machine
--
-- Pre-requisites:
--   - BLUE player slot occupied (UH-1H or any transport)
--   - TRZ zone "TRZ_alpha_B_10_nil_0" in mission
--   - ctldLogPath set via patch_logpath.lua after each CTLD_Next injection
--
-- Steps:
--   1. Spawn 4 RED Hummers ~300m south + create "Test2JTAC" template (inf=4, jtac=2)
--   2. Simulate TRZ embark → TRZ_LOADED in _inTransit, 0 JTAC registered (no lasing)
--   3. Deploy → 2 JTACs registered + startLaseTroopUnit; wait 10s then re-inject step 4
--   4. Re-embark → verify _claimedTargets=2 (distinct targets), deregisterJTAC x2 → verify empty
--   5. Re-deploy → startLaseTroopUnit x2; wait 10s then re-inject step 6
--   6. 1 JTAC dead (onUnitDead) → its target freed (_claimedTargets: 2→1); alive JTAC keeps claim
--   7. Timer-driven destruction of all targets → successive reacquisition by alive JTAC
--      Phase A (first injection): install timer → re-inject in ~50s
--      Phase B (re-injection): validate claimLog shows ≥2 distinct targets claimed
--   8. Final report + cleanupAll
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[TFC] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG    = "[TFC]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_TFC_STEP"

-- ── HELPERS ───────────────────────────────────────────────────────────────────

local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end

local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 30)
    log(msg)
end

local function pass(msg)
    report("[PASS] " .. msg)
end

local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end

local function check(id, desc, condition, details)
    if condition then
        pass(id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (details and (" | " .. details) or ""))
    end
end

local function assert_eq(id, actual, expected)
    check(id, "eq", actual == expected,
        "expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function assert_not_nil(id, val, desc)
    check(id, desc or "not nil", val ~= nil, "got nil")
end

--- Count entries in a hash table (# only works on arrays in Lua 5.1).
local function countPairs(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local TEST_TMPL_NAME = "Test2JTAC"

-- ── STATE MACHINE INIT ────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]

-- Start banner: outText + CTLD.log, timestamp differentiates successive runs
report("==== START " .. START .. " | step=" .. step .. " ====")

-- Log reset at step 1: clean CTLD.log for a fresh run
if step == 1 then
    pcall(function()
        ctld.utils.closeLog()
        local f = io.open((cfg.settings["ctldLogPath"] or "") .. "CTLD.log", "w")
        if f then
            f:write("[" .. START .. "] === LOG RESET — new run ===\n")
            f:close()
        end
        ctld.utils.reopenLogAppend()
    end)
end

-- Step timer
local _step_start = os.clock()
local _result = "INCOMPLETE"

-- ── MODULE-LEVEL STATE (shared between helpers and pcall closure) ─────────────
local playerName = nil
local pPos       = nil

-- ── CLEANUP HELPER ────────────────────────────────────────────────────────────
local function cleanupAll()
    local troopMgr = CTLDTroopManager.getInstance()
    if not troopMgr then log("cleanupAll: CTLDTroopManager not ready, skipping"); return end
    local jtacMgr = CTLDJTACManager and CTLDJTACManager.get() or nil

    -- Destroy any spawned DCS groups still alive
    for coa = 1, 2 do
        for _, gname in ipairs(troopMgr._droppedGroups[coa] or {}) do
            local g = Group.getByName(gname)
            if g and g:isExist() then g:destroy() end
        end
        troopMgr._droppedGroups[coa] = {}
    end

    -- Deregister any JTAC entries linked to in-transit groups
    if jtacMgr then
        for uname, grp in pairs(troopMgr._inTransit or {}) do
            if grp and grp._jtacUnits then
                for jname in pairs(grp._jtacUnits) do
                    jtacMgr.jtacs[jname] = nil
                end
            end
        end
    end
    troopMgr._inTransit = {}

    -- Remove the test template from registry + templates list
    if CTLDObjectRegistry then
        for i, t in ipairs(troopMgr._templates or {}) do
            if t.name == TEST_TMPL_NAME then
                CTLDObjectRegistry._db[t._dbKey] = nil
                table.remove(troopMgr._templates, i)
                break
            end
        end
    end

    troopMgr._droppedTemplates = {}

    -- Reset JTAC claimed targets (avoids cross-run residual claims)
    if jtacMgr then jtacMgr._claimedTargets = {} end

    -- Destroy RED target vehicle group if still alive
    local tgtGname = _G["_TFC_TARGET_GROUP"]
    if tgtGname then
        local tgtGrp = Group.getByName(tgtGname)
        if tgtGrp and tgtGrp:isExist() then tgtGrp:destroy() end
        _G["_TFC_TARGET_GROUP"] = nil
    end

    log("cleanupAll done")
end

-- ── SPAWN HELPER ──────────────────────────────────────────────────────────────
-- Spawns a test DCS group with unit names matching the real CTLD naming convention
-- (JTAC-N prefix for JTAC units, INF-N for infantry) so _syncFromDCSGroup works.
local function spawnTroopGroup(tmpl, coalitionId, countryId, x, z, hdg)
    local troopMgr = CTLDTroopManager.getInstance()
    local units    = {}
    local idx      = 0

    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = tmpl[role] or 0
        for _ = 1, n do
            idx = idx + 1
            local namePrefix = (role == "jtac") and "JTAC" or "INF"
            local uid        = ctld.utils.getNextUniqId()
            local unitType   = (role == "jtac") and "Soldier AK" or "Soldier AK"
            units[idx] = {
                name    = string.format("%s-%d", namePrefix, uid),
                type    = unitType,
                x       = x + (idx - 1) * 3,
                y       = z,
                heading = hdg or 0,
                skill   = "Average",
            }
        end
    end

    local gname = string.format("TroopGrp_%s_%d", tmpl.name, ctld.utils.getNextUniqId())
    local grpDef = {
        name  = gname,
        task  = "Ground Nothing",
        units = units,
    }

    local dcsGroup = coalition.addGroup(countryId, Group.Category.GROUND, grpDef)
    if not dcsGroup then fail("coalition.addGroup failed") end

    -- Register in _droppedGroups
    table.insert(troopMgr._droppedGroups[coalitionId], dcsGroup:getName())
    -- Register in _droppedTemplates with enriched format (BUG-06/07 fix)
    troopMgr._droppedTemplates[dcsGroup:getName()] = {
        key    = tmpl._dbKey,
        name   = tmpl.name,
        weight = tmpl.total * 124,
        total  = tmpl.total,
    }

    return dcsGroup
end

-- ══════════════════════════════════════════════════════════════════════════════
-- STATE MACHINE (wrapped in pcall — cleanup always runs)
-- ══════════════════════════════════════════════════════════════════════════════
local _ok, _err = pcall(function()

-- Player resolution (fail is caught by pcall → cleanup runs)
do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    local pu = units[1]
    if not pu or not pu:isExist() then
        fail("ABORT: no BLUE player — occupy a slot first")
    end
    playerName = pu:getName()
    pPos       = pu:getPoint()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Cleanup + spawn 4 RED Hummers + create 2-JTAC template
-- Expected: 4 RED vehicles ~300m south; template hasJtac=true, jtac=2, total=6
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cleanupAll()

    -- Spawn 4 unarmed RED Hummers ~300m south as JTAC target pool.
    -- unit.x = world-x (East), unit.y = world-z (North) in DCS ground coords.
    -- Spread east-west by 25m so each unit is individually targetable.
    -- country.id.RUSSIA = RED coalition in standard DCS (USA = BLUE).
    do
        local units = {}
        for i = 1, 4 do
            units[i] = {
                name    = string.format("TFC_Target_%d", ctld.utils.getNextUniqId()),
                type    = "Hummer",
                x       = pPos.x + (i - 2) * 25,
                y       = pPos.z - 300,
                heading = 0,
                skill   = "Average",
            }
        end
        local tgtGrp = coalition.addGroup(country.id.RUSSIA, Group.Category.GROUND, {
            name  = string.format("TFC_Targets_%d", ctld.utils.getNextUniqId()),
            task  = "Ground Nothing",
            units = units,
        })
        if tgtGrp then
            _G["_TFC_TARGET_GROUP"] = tgtGrp:getName()
            -- Store individual unit names for step 7 timer-driven destruction
            local unames = {}
            for _, u in ipairs(tgtGrp:getUnits() or {}) do
                unames[#unames + 1] = u:getName()
            end
            _G["_TFC_TARGET_UNITS"] = unames
            log("Step 1: RED targets spawned — group='" .. tgtGrp:getName()
                .. "' (" .. #unames .. "x Hummer RED, ~300m south)")
        else
            log("Step 1: WARNING — RED target group spawn failed")
        end
    end

    local troopMgr = CTLDTroopManager.getInstance()
    assert_not_nil("F-T1.1", troopMgr, "CTLDTroopManager available")

    local ok, err = troopMgr:createLoadableGroup({
        name        = TEST_TMPL_NAME,
        composition = { inf = 4, jtac = 2 },
        side        = coalition.side.BLUE,
    })
    check("F-T1.2", "createLoadableGroup ok", ok, tostring(err))

    local tmpl = troopMgr:_findTemplate(TEST_TMPL_NAME)
    assert_not_nil("F-T1.3", tmpl, "template found after creation")
    check("F-T1.4", "hasJtac=true", tmpl.hasJtac == true, tostring(tmpl.hasJtac))
    assert_eq("F-T1.5", tmpl.jtac, 2)
    assert_eq("F-T1.6", tmpl.inf,  4)

    log("Step 1: template created hasJtac=" .. tostring(tmpl.hasJtac)
        .. " jtac=" .. tmpl.jtac .. " inf=" .. tmpl.inf .. " total=" .. tostring(tmpl.total))
    pass("Step 1 — RED targets spawned, 2-JTAC template created (inf=4, jtac=2). Re-inject for Step 2.")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Simulate TRZ embark → TRZ_LOADED group in _inTransit (no lasing)
-- Expected: group in _inTransit, state=TRZ_LOADED, 0 JTAC registered in jtacMgr
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local troopMgr = CTLDTroopManager.getInstance()
    local jtacMgr  = CTLDJTACManager and CTLDJTACManager.get() or nil
    local tmpl = troopMgr:_findTemplate(TEST_TMPL_NAME)
    assert_not_nil("F-T2.1", tmpl, "template found — run Step 1 first")

    -- Build virtual slot maps (mirrors embarkFromTroopZone)
    local allAliveUnits = {}
    local jtacUnits     = {}
    local unitIndex     = 0
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = tmpl[role] or 0
        for _ = 1, n do
            unitIndex = unitIndex + 1
            local slotName = string.format("%s_u%d", tmpl.name, unitIndex)
            allAliveUnits[slotName] = unitIndex
            if role == "jtac" then jtacUnits[slotName] = true end
        end
    end

    local grp = CTLDTroopGroup:new({
        templateKey  = tmpl._dbKey,
        templateName = tmpl.name,
        unitTotal    = tmpl.total,
        weight       = tmpl.total * 124,
        coalitionId  = coalition.side.BLUE,
        countryId    = country.id.USA,
        state        = CTLDTroopGroup.STATE.TRZ_LOADED,
        _aliveUnits  = allAliveUnits,
        _jtacUnits   = jtacUnits,
    })
    assert_not_nil("F-T2.2", grp, "CTLDTroopGroup:new() returned object")
    troopMgr._inTransit[playerName] = grp

    local jtacCount  = countPairs(grp._jtacUnits)
    local totalCount = countPairs(grp._aliveUnits)
    check("F-T2.3", "state=TRZ_LOADED", grp.state == CTLDTroopGroup.STATE.TRZ_LOADED, grp.state)
    assert_eq("F-T2.4", jtacCount, 2)
    assert_eq("F-T2.5", totalCount, 6)

    -- No JTAC registered yet — troops are in transit, no lasing
    local jtacMgrCount = jtacMgr and countPairs(jtacMgr.jtacs) or 0
    check("F-T2.6", "no JTAC registered in jtacMgr while in transit",
        jtacMgr == nil or not jtacMgr.jtacs[tmpl.name .. "_u5"],
        "unexpected JTAC entry found")

    log("Step 2: TRZ_LOADED | templateKey=" .. grp.templateKey
        .. " | total=" .. totalCount .. " | jtac=" .. jtacCount
        .. " | jtacMgr.jtacs=" .. jtacMgrCount .. " (no lasing while embarked)")
    pass("Step 2 — TRZ_LOADED, no JTAC active (troops embarked). Re-inject for Step 3 (deploy).")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Deploy → 2 JTACs registered + lasing 2 distinct targets
-- Expected: _jtacUnits=2, startLaseTroopUnit x2; wait 10s for autoLaseLoop
--           then re-inject for Step 4 which checks _claimedTargets
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local troopMgr = CTLDTroopManager.getInstance()
    local jtacMgr  = CTLDJTACManager and CTLDJTACManager.get() or nil
    assert_not_nil("F-T3.1", jtacMgr, "CTLDJTACManager available")

    local grp = troopMgr._inTransit[playerName]
    assert_not_nil("F-T3.2", grp, "TRZ_LOADED group in _inTransit — run Step 2 first")

    local tmpl = troopMgr:_findTemplate(TEST_TMPL_NAME)
    assert_not_nil("F-T3.3", tmpl, "template found")

    -- Spawn at helicopter position facing south (LOS to RED vehicles 300m south)
    local dcsGroup = spawnTroopGroup(tmpl, coalition.side.BLUE, country.id.USA,
        pPos.x + 5, pPos.z, 180)
    assert_not_nil("F-T3.4", dcsGroup, "DCS group spawned")

    grp.dcsGroup = dcsGroup
    grp.state    = "DEPLOYED"
    grp:_syncFromDCSGroup(dcsGroup)  -- BUG-03 fix: rebuilds _jtacUnits from real DCS names

    local jtacCount  = countPairs(grp._jtacUnits)
    local aliveCount = countPairs(grp._aliveUnits)
    check("F-T3.5", "state=DEPLOYED", grp.state == "DEPLOYED", grp.state)
    assert_eq("F-T3.6", jtacCount, 2)
    assert_eq("F-T3.7", aliveCount, 6)

    for uname in pairs(grp._jtacUnits) do
        check("F-T3.8", "JTAC unit has JTAC prefix",
            uname:match("^JTAC") ~= nil, "unitName=" .. uname)
        break
    end

    -- Start lasing — autoLaseLoop will claim targets asynchronously (timer-based)
    local registeredNames = {}
    for uname in pairs(grp._jtacUnits) do
        jtacMgr:startLaseTroopUnit(uname)
        registeredNames[#registeredNames + 1] = uname
    end
    _G["_TFC_JTAC_NAMES"] = registeredNames
    troopMgr._inTransit[playerName] = nil

    log("Step 3: DEPLOYED group='" .. dcsGroup:getName() .. "' alive=" .. aliveCount
        .. " jtac=" .. jtacCount .. " startLaseTroopUnit x" .. #registeredNames
        .. " jtacMgr.jtacs=" .. countPairs(jtacMgr.jtacs))
    pass("Step 3 — deployed, 2 JTACs lasing started. WAIT 10s for autoLaseLoop — re-inject for Step 4.")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Re-embark: 2 JTACs idle, targets freed
-- Verify _claimedTargets has 2 entries (from step 3 lasing), then deregister both
-- Expected: after deregister, _claimedTargets empty; targets available again
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    local troopMgr = CTLDTroopManager.getInstance()
    local jtacMgr  = CTLDJTACManager and CTLDJTACManager.get() or nil
    assert_not_nil("F-T4.1", jtacMgr, "CTLDJTACManager available")

    local jtacNames = _G["_TFC_JTAC_NAMES"] or {}
    check("F-T4.2", "step 3 registered 2 JTACs",
        #jtacNames >= 2, "got " .. #jtacNames .. " — run Step 3 first")

    -- Verify _claimedTargets has 2 distinct entries (one per JTAC)
    local claimedBefore = countPairs(jtacMgr._claimedTargets)
    check("F-T4.3", "_claimedTargets has >=2 entries (both JTACs lasing)",
        claimedBefore >= 2, "got " .. claimedBefore .. " — wait longer after step 3")
    -- Verify the 2 claimed targets are different
    local claimedTargetNames = {}
    for tgt in pairs(jtacMgr._claimedTargets) do
        claimedTargetNames[#claimedTargetNames + 1] = tgt
    end
    check("F-T4.4", "2 distinct targets claimed (deconfliction)",
        claimedTargetNames[1] ~= claimedTargetNames[2],
        "targets: " .. (claimedTargetNames[1] or "?") .. " / " .. (claimedTargetNames[2] or "?"))

    -- Simulate re-embark: deregisterJTAC both (mirrors embarkFromField)
    local deregCount = 0
    for _, uname in ipairs(jtacNames) do
        if jtacMgr.jtacs[uname] then
            jtacMgr:deregisterJTAC(uname)
            log("Step 4: deregisterJTAC('" .. uname .. "')")
            deregCount = deregCount + 1
        end
    end

    -- Destroy deployed DCS group
    local deployedGrp = nil
    for _, gname in ipairs(troopMgr._droppedGroups[coalition.side.BLUE] or {}) do
        local g = Group.getByName(gname)
        if g and g:isExist() then
            deployedGrp = g
            troopMgr:_removeFromDropped(coalition.side.BLUE, gname)
            troopMgr._droppedTemplates[gname] = nil
            g:destroy()
            log("Step 4: group:destroy() called for '" .. gname .. "'")
            break
        end
    end

    -- Verify _claimedTargets now empty (targets freed for other JTACs)
    local claimedAfter = countPairs(jtacMgr._claimedTargets)
    assert_eq("F-T4.5", claimedAfter, 0)
    assert_eq("F-T4.6", deregCount, 2)

    _G["_TFC_JTAC_NAMES"] = nil
    log("Step 4: deregCount=" .. deregCount .. " claimedBefore=" .. claimedBefore
        .. " claimedAfter=" .. claimedAfter .. " (targets freed)")
    pass("Step 4 — re-embark: " .. deregCount .. " JTACs idle, _claimedTargets empty. Re-inject for Step 5.")
    _G[STEP_N] = 5
    _result = "step=4 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 5 — Re-deploy → 2 JTACs lasing 2 distinct targets (2nd cycle)
-- Expected: same as step 3 but from a field re-deploy; wait 10s then re-inject
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 5 then

    local troopMgr = CTLDTroopManager.getInstance()
    local jtacMgr  = CTLDJTACManager and CTLDJTACManager.get() or nil
    assert_not_nil("F-T5.1", jtacMgr, "CTLDJTACManager available")

    local tmpl = troopMgr:_findTemplate(TEST_TMPL_NAME)
    assert_not_nil("F-T5.2", tmpl, "template found — run Step 1 first")

    -- Spawn again at helicopter, facing south
    local dcsGroup = spawnTroopGroup(tmpl, coalition.side.BLUE, country.id.USA,
        pPos.x + 5, pPos.z, 180)
    assert_not_nil("F-T5.3", dcsGroup, "DCS group spawned")

    local grp5 = CTLDTroopGroup:new({
        templateKey  = tmpl._dbKey,
        templateName = tmpl.name,
        unitTotal    = tmpl.total,
        weight       = 0,
        coalitionId  = coalition.side.BLUE,
        countryId    = country.id.USA,
        state        = CTLDTroopGroup.STATE.TRZ_LOADED,
    })
    grp5:_syncFromDCSGroup(dcsGroup)

    local jtacCount = countPairs(grp5._jtacUnits)
    check("F-T5.4", "_syncFromDCSGroup found 2 JTAC units",
        jtacCount == 2, "jtacCount=" .. jtacCount)

    local registeredNames = {}
    for uname in pairs(grp5._jtacUnits) do
        jtacMgr:startLaseTroopUnit(uname)
        registeredNames[#registeredNames + 1] = uname
    end
    _G["_TFC_JTAC_NAMES"] = registeredNames
    assert_eq("F-T5.5", #registeredNames, 2)

    log("Step 5: re-deploy group='" .. dcsGroup:getName() .. "' jtac=" .. jtacCount
        .. " startLaseTroopUnit x" .. #registeredNames)
    pass("Step 5 — re-deployed, 2 JTACs lasing. WAIT 10s for autoLaseLoop — re-inject for Step 6.")
    _G[STEP_N] = 6
    _result = "step=5 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 6 — 1 JTAC destroyed → its target freed, other JTAC keeps its claim
-- Expected: _claimedTargets goes from 2 to 1; dead JTAC's target no longer blocked
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 6 then

    local troopMgr = CTLDTroopManager.getInstance()
    local jtacMgr  = CTLDJTACManager and CTLDJTACManager.get() or nil
    assert_not_nil("F-T6.1", jtacMgr, "CTLDJTACManager available")

    local jtacNames = _G["_TFC_JTAC_NAMES"] or {}
    check("F-T6.2", "step 5 registered 2 JTACs",
        #jtacNames >= 2, "got " .. #jtacNames .. " — run Step 5 first")

    -- Verify both JTACs have claimed targets
    local claimedBefore = countPairs(jtacMgr._claimedTargets)
    check("F-T6.3", "_claimedTargets has >=2 entries before kill",
        claimedBefore >= 2, "got " .. claimedBefore .. " — wait longer after step 5")

    -- Find the dead JTAC's target BEFORE killing it
    local deadUnitName = jtacNames[2]
    local aliveUnitName = jtacNames[1]
    local deadJtacTarget = nil
    for tgt, owner in pairs(jtacMgr._claimedTargets) do
        if owner == deadUnitName then deadJtacTarget = tgt end
    end
    log("Step 6: killing JTAC '" .. deadUnitName
        .. "' | its target='" .. tostring(deadJtacTarget) .. "'")

    -- Simulate S_EVENT_DEAD for the JTAC unit
    troopMgr:onUnitDead(deadUnitName)

    -- Verify: dead JTAC removed, its target freed, alive JTAC still claims its target
    check("F-T6.4", "dead JTAC removed from jtacMgr",
        jtacMgr.jtacs[deadUnitName] == nil, "still present")
    local claimedAfter = countPairs(jtacMgr._claimedTargets)
    assert_eq("F-T6.5", claimedAfter, 1)
    if deadJtacTarget then
        check("F-T6.6", "dead JTAC's target released from _claimedTargets",
            jtacMgr._claimedTargets[deadJtacTarget] == nil, "still claimed")
    end
    check("F-T6.7", "alive JTAC still in jtacMgr",
        jtacMgr.jtacs[aliveUnitName] ~= nil, "alive JTAC missing")

    -- Store alive JTAC key for step 7 monitoring
    _G["_TFC_ALIVE_JTAC"]  = aliveUnitName
    _G["_TFC_JTAC_NAMES"]  = nil
    _G["_TFC_STEP7_DONE"]  = nil  -- reset step 7 monitor flag

    log("Step 6: claimedBefore=" .. claimedBefore .. " claimedAfter=" .. claimedAfter
        .. " aliveJtac='" .. aliveUnitName .. "'")
    pass("Step 6 — 1 JTAC dead: target freed, alive JTAC keeps claim. Re-inject for Step 7.")
    _G[STEP_N] = 7
    _result = "step=6 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 7 — Timer-driven destruction of all targets → validate successive reacquisition
-- Phase A (first injection): install timer + return "re-inject in 40s"
-- Phase B (re-injection when done): validate claim log shows ≥2 distinct claims
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 7 then

    local jtacMgr = CTLDJTACManager and CTLDJTACManager.get() or nil
    assert_not_nil("F-T7.1", jtacMgr, "CTLDJTACManager available")

    -- Phase B: re-injection after timer completes
    if _G["_TFC_STEP7_DONE"] == true then
        log("Step 7 Phase B: reading CTLD.log for claim validation")

        -- Read CTLD.log from CLAIM_WINDOW_START marker to collect distinct targets claimed
        local logPath = (cfg.settings["ctldLogPath"] or "") .. "CTLD.log"
        local allTargetsSeen = {}
        local startFound = false
        pcall(ctld.utils.closeLog)
        local f = io.open(logPath, "r")
        if f then
            for line in f:lines() do
                if not startFound then
                    if line:find("Step7 CLAIM_WINDOW_START", 1, true) then
                        startFound = true
                    end
                else
                    -- claim: arrow may be → (UTF-8) or ->, so capture last quoted token on the line
                    if line:find("claim:", 1, true) then
                        local tgt = line:match("'([^']+)'%s*$")
                        if tgt then allTargetsSeen[tgt] = true end
                    end
                    -- release lines also reveal a target that was held (counts as distinct)
                    if line:find("release claim on", 1, true) then
                        local tgt = line:match("release claim on '([^']+)'")
                        if tgt then allTargetsSeen[tgt] = true end
                    end
                end
            end
            f:close()
        end
        pcall(ctld.utils.reopenLogAppend)
        local distinctTargets = countPairs(allTargetsSeen)
        log("Step 7 Phase B: distinctTargets=" .. distinctTargets .. " startFound=" .. tostring(startFound))
        -- Alive JTAC should have claimed at least 2 different targets
        -- (current + at least 1 reacquisition after first target destroyed)
        check("F-T7.2", "alive JTAC reacquired targets successively (>=2 distinct targets claimed)",
            distinctTargets >= 2, "only " .. distinctTargets .. " distinct target(s) seen in log")

        -- None of our test targets should remain in _claimedTargets
        -- (JTAC may have picked up other mission RED units — that is correct behaviour)
        local testTargets = _G["_TFC_TARGET_UNITS"] or {}
        local testTargetSet = {}
        for _, n in ipairs(testTargets) do testTargetSet[n] = true end
        local ourTargetsClaimed = 0
        for tgt in pairs(jtacMgr._claimedTargets) do
            if testTargetSet[tgt] then ourTargetsClaimed = ourTargetsClaimed + 1 end
        end
        check("F-T7.3", "none of our test targets remain claimed (all freed after destroy)",
            ourTargetsClaimed == 0, "still " .. ourTargetsClaimed .. " test target(s) claimed")

        _G["_TFC_STEP7_DONE"]      = nil
        _G["_TFC_STEP7_CLAIM_LOG"] = nil
        log("Step 7: successive reacquisition validated — distinctTargets=" .. distinctTargets)
        pass("Step 7 — all targets destroyed, reacquisition chain validated. Re-inject for Step 8.")
        _G[STEP_N] = 8
        _result = "step=7 SUCCESS"

    else
        -- Phase A: install timer-driven sequence
        local aliveJtacKey  = _G["_TFC_ALIVE_JTAC"]
        local targetUnits   = _G["_TFC_TARGET_UNITS"] or {}
        check("F-T7.4", "alive JTAC key stored from step 6",
            aliveJtacKey ~= nil, "run Step 6 first")
        check("F-T7.5", "target unit list available",
            #targetUnits >= 1, "run Step 1 first")

        -- Initialize monitoring state
        _G["_TFC_STEP7_CLAIM_LOG"] = {}
        _G["_TFC_STEP7_DONE"]      = false
        _G["_TFC_STEP7_IDX"]       = 1

        -- Timer: every 8s, snapshot _claimedTargets then destroy next target unit.
        -- 8s > autoLaseLoop searchInterval (~5s) — enough time for reacquisition.
        timer.scheduleFunction(function(_, t)
            local jm      = CTLDJTACManager and CTLDJTACManager.get()
            local idx     = _G["_TFC_STEP7_IDX"]
            local targets = _G["_TFC_TARGET_UNITS"] or {}

            -- Snapshot current claims
            local snapshot = {}
            if jm then
                for tgt, owner in pairs(jm._claimedTargets) do
                    snapshot[tgt] = owner
                end
            end
            local claimLog = _G["_TFC_STEP7_CLAIM_LOG"] or {}
            claimLog[#claimLog + 1] = { idx = idx, claims = snapshot }
            _G["_TFC_STEP7_CLAIM_LOG"] = claimLog

            -- Destroy next target unit
            if idx <= #targets then
                local u = Unit.getByName(targets[idx])
                if u and u:isExist() then
                    ctld.utils.log("INFO", "[TFC] Step7 timer: destroying target '%s' (idx=%d)", targets[idx], idx)
                    u:destroy()
                else
                    ctld.utils.log("INFO", "[TFC] Step7 timer: target '%s' already gone (idx=%d)", targets[idx], idx)
                end
                _G["_TFC_STEP7_IDX"] = idx + 1
                return t + 12  -- next cycle in 12s (autoLaseLoop needs ~10s to reacquire)
            else
                -- All targets processed — wait one more cycle for final reacquisition attempt
                ctld.utils.log("INFO", "[TFC] Step7 timer: all targets destroyed, final claim snapshot done")
                _G["_TFC_STEP7_DONE"] = true
                return nil  -- stop timer
            end
        end, nil, timer.getTime() + 3)

        log("Step7 CLAIM_WINDOW_START")
        log("Step 7 Phase A: monitoring timer installed | aliveJtac='" .. tostring(aliveJtacKey)
            .. "' | targets=" .. #targetUnits .. " | interval=8s per target")
        pass("Step 7 — timer running (destroys 1 target every 8s). RE-INJECT IN ~" .. (#targetUnits * 8 + 15) .. "s.")
        -- Stay at step 7 so re-injection hits Phase B
        _result = "step=7 MONITORING"
    end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 8 — Final report + full cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 8 then

    local troopMgr = CTLDTroopManager.getInstance()
    local jtacMgr  = CTLDJTACManager and CTLDJTACManager.get() or nil

    local droppedBlue = #(troopMgr._droppedGroups[coalition.side.BLUE] or {})
    local inTransit   = countPairs(troopMgr._inTransit)
    local jtacCount   = jtacMgr and countPairs(jtacMgr.jtacs) or -1

    log("Final: droppedGroups[BLUE]=" .. droppedBlue
        .. " inTransit=" .. inTransit .. " jtacs=" .. jtacCount)

    report("═══════════════════════════════════════")
    report("SCENARIO COMPLETE — Full Troop + JTAC Deconfliction Cycle")
    report("S1: spawn RED targets + template")
    report("S2: embark (TRZ_LOADED, no lasing)")
    report("S3: deploy → 2 JTACs lasing")
    report("S4: re-embark → 2 JTACs idle, targets freed")
    report("S5: re-deploy → 2 JTACs lasing 2nd cycle")
    report("S6: 1 JTAC dead → target released, other keeps claim")
    report("S7: all targets destroyed → successive reacquisition validated")
    report("droppedGroups[BLUE]=" .. droppedBlue
        .. " | inTransit=" .. inTransit .. " | jtacMgr=" .. jtacCount)
    report("═══════════════════════════════════════")

    cleanupAll()
    _G["_TFC_ALIVE_JTAC"]      = nil
    _G["_TFC_TARGET_UNITS"]    = nil
    _G["_TFC_STEP7_CLAIM_LOG"] = nil
    _G["_TFC_STEP7_DONE"]      = nil
    _G["_TFC_STEP7_IDX"]       = nil
    _G[STEP_N] = 1
    report("Cleanup done. Re-inject to restart from Step 1.")
    _result = "ALL SUCCESS"

-- ── INCOMPLETE guard ──────────────────────────────────────────────────────────
else
    fail("step=" .. step .. " has no matching branch — reset with _reset_steps.lua or add elseif")
end

end)  -- end pcall

-- ── CLEANUP (always executed — debug restored even if fail() was called) ──────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

-- ── WITCHCRAFT RETURN VALUE ───────────────────────────────────────────────────
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
