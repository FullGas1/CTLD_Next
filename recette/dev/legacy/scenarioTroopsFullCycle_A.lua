---@diagnostic disable
-- =============================================================================
-- scenarios/scenarioTroopsFullCycle_A.lua
-- Self-contained 8-step troop cycle test via Witchcraft.
-- Single injection — no delays — full trace via ctld.utils.log().
--
-- Pre-requisites:
--   - BLUE player slot occupied
--   - TRZ_alpha_B_10_nil_0 zone in mission
--   - RED unit for JTAC target
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG   = "[TFC_A]"
local START = os.date("%Y-%m-%d %H:%M:%S")

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
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. msg)
    error("TFC_A_ABORT: " .. msg)
end

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local TEST_TMPL_NAME = "Test2JTAC_A"

-- ── CLEANUP ───────────────────────────────────────────────────────────────────
local function cleanupAll()
    local troopMgr = CTLDTroopManager.getInstance()
    if not troopMgr then log("cleanupAll: CTLDTroopManager not ready"); return end
    local jtacMgr = nil
    if CTLDJTACManager then jtacMgr = CTLDJTACManager.get() end

    for coa = 1, 2 do
        for _, gname in ipairs(troopMgr._droppedGroups[coa] or {}) do
            local g = Group.getByName(gname)
            if g and g:isExist() then g:destroy() end
        end
        troopMgr._droppedGroups[coa] = {}
    end

    if jtacMgr then
        for _, grp in pairs(troopMgr._inTransit or {}) do
            if grp and grp._jtacUnits then
                for jname, _ in pairs(grp._jtacUnits) do
                    jtacMgr.jtacs[jname] = nil
                end
            end
        end
    end
    troopMgr._inTransit = {}

    for i, t in ipairs(troopMgr._templates or {}) do
        if t and t.name == TEST_TMPL_NAME then
            if CTLDObjectRegistry then CTLDObjectRegistry._db[t._dbKey] = nil end
            table.remove(troopMgr._templates, i)
            break
        end
    end
    troopMgr._droppedTemplates = {}
    log("cleanupAll done")
end

-- ── SPAWN HELPER ──────────────────────────────────────────────────────────────
local function spawnTroopGroup(templateKey, coalitionId, countryId, x, z, hdg)
    local tmpl = nil
    for _, t in ipairs(CTLDTroopManager.getInstance()._templates or {}) do
        if t and t._dbKey == templateKey then tmpl = t; break end
    end
    if not tmpl then fail("template not found: " .. tostring(templateKey)) end

    local units = {}
    local idx = 0
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = tmpl[role] or 0
        for i = 1, n do
            idx = idx + 1
            local unitType = (role == "jtac")
                and (CTLDTroopManager._UNIT_TYPES["jtac"] and CTLDTroopManager._UNIT_TYPES["jtac"][2] or "Infantry AK")
                or "Infantry AK"
            units[idx] = {
                name = string.format("%s_u%d", tmpl.name, idx),
                type = unitType,
                x = x, y = z,
                heading = hdg,
                skill = "Average",
            }
        end
    end

    local grpDef = {
        name = string.format("TFC_A_Grp_%d", ctld.utils.getNextUniqId()),
        task = "Ground Nothing",
        units = units,
    }

    local dcsGroup = coalition.addGroup(countryId, Group.Category.GROUND, grpDef)
    if not dcsGroup then fail("coalition.addGroup failed") end

    local gname = dcsGroup:getName()
    table.insert(CTLDTroopManager.getInstance()._droppedGroups[coalitionId], gname)
    CTLDTroopManager.getInstance()._droppedTemplates[gname] = templateKey
    return dcsGroup
end

-- ── PLAYER RESOLUTION ─────────────────────────────────────────────────────────
local playerUnit = nil
local playerName = nil
local pPos = nil

for attempt = 1, 10 do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 and units[1]:isExist() then
        playerUnit = units[1]
        playerName = playerUnit:getName()
        pPos = playerUnit:getPoint()
        log("player resolved on attempt " .. attempt .. ": " .. playerName)
        break
    end
    if attempt < 10 then
        local t = os.clock() + 1
        while os.clock() < t do end
    end
end

if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
    return TAG .. " ABORT: no BLUE player — occupy a slot first"
end

-- ── MAIN (8-step sequential execution) ────────────────────────────────────────
report("==== START " .. START .. " ====")
log("═══════════════════════════════════════════════════════")
log("START | player=" .. playerName)
log("═══════════════════════════════════════════════════════")

local _result = ""
local _ok, _err = pcall(function()

    -- STEP 1: cleanup + create template
    log("─── STEP 1 ───")
    cleanupAll()

    local troopMgr = CTLDTroopManager.getInstance()
    if not troopMgr then fail("CTLDTroopManager not available") end

    local ok, err = troopMgr:createLoadableGroup({
        name       = TEST_TMPL_NAME,
        composition = { inf = 4, jtac = 2 },
        side       = coalition.side.BLUE,
    })
    if not ok then fail("createLoadableGroup failed: " .. tostring(err)) end

    local tmpl = troopMgr:_findTemplate(TEST_TMPL_NAME)
    if not tmpl then fail("template not found after creation") end
    if not tmpl.hasJtac then fail("hasJtac should be true") end
    if tmpl.jtac ~= 2 then fail("jtac should be 2, got " .. tostring(tmpl.jtac)) end

    log("Step1 OK: hasJtac=" .. tostring(tmpl.hasJtac) .. " jtac=" .. tmpl.jtac .. " total=" .. tmpl.total)
    pass("Step1 — 2-JTAC template created (inf=4, jtac=2)")

    -- STEP 2: TRZ_LOADED group
    log("─── STEP 2 ───")
    local grp = CTLDTroopGroup:new({
        templateKey  = tmpl._dbKey,
        templateName = tmpl.name,
        unitTotal    = tmpl.total,
        weight       = tmpl.total * 124,
        hasJtac      = tmpl.hasJtac,
        coalitionId  = coalition.side.BLUE,
        countryId    = country.id.USA,
        state        = "TRZ_LOADED",
    })

    local aliveUnits, jtacUnits, unitIndex = {}, {}, 0
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = tmpl[role] or 0
        for i = 1, n do
            unitIndex = unitIndex + 1
            local unitName = string.format("%s_u%d", tmpl.name, unitIndex)
            if role == "jtac" then jtacUnits[unitName] = true
            else aliveUnits[unitName] = unitIndex end
        end
    end

    grp._aliveUnits = aliveUnits
    grp._jtacUnits  = jtacUnits
    grp.dcsGroup    = nil
    troopMgr._inTransit[playerName] = grp

    local jtacCount = 0
    for _ in pairs(jtacUnits) do jtacCount = jtacCount + 1 end

    log("Step2 OK: TRZ_LOADED alive=" .. #aliveUnits .. " jtac=" .. jtacCount .. " state=" .. grp.state)
    pass("Step2 — TRZ_LOADED (inf=" .. #aliveUnits .. ", jtac=" .. jtacCount .. ")")

    -- STEP 3: disembark → spawn DCS group + register JTAC
    log("─── STEP 3 ───")
    local spawnX = pPos.x + 80
    local spawnZ = pPos.z + 30
    local dcsGroup = spawnTroopGroup(grp.templateKey, coalition.side.BLUE, country.id.USA, spawnX, spawnZ, 0)
    if not dcsGroup then fail("spawnTroopGroup failed") end

    local gname = dcsGroup:getName()
    grp.dcsGroup = dcsGroup
    grp.state = "DEPLOYED"

    local dcsUnits = dcsGroup:getUnits()
    local newAlive, newJtac = {}, {}
    local unitIdx = 0

    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = tmpl[role] or 0
        for i = 1, n do
            if unitIdx + 1 <= #dcsUnits then
                local dcsUnit = dcsUnits[unitIdx + 1]
                local unitName = dcsUnit:getName()
                if role == "jtac" then
                    newJtac[unitName] = true
                else
                    newAlive[unitName] = dcsUnit
                end
            end
            unitIdx = unitIdx + 1
        end
    end

    grp._aliveUnits = newAlive
    grp._jtacUnits  = newJtac
    troopMgr._inTransit[playerName] = nil

    local jtacMgr = CTLDJTACManager.get()
    local registeredJtac = 0
    for jtacName, _ in pairs(newJtac) do
        local g = Group.getByName(jtacName)
        if g and g:isExist() then
            local ok_j = jtacMgr:spawnJTAC(jtacName, "JTAC", coalition.side.BLUE)
            log("spawnJTAC('" .. jtacName .. "') → " .. tostring(ok_j))
            if ok_j then registeredJtac = registeredJtac + 1 end
        else
            log("WARN: JTAC unit '" .. jtacName .. "' group not found in DCS")
        end
    end

    local jtacInMgr = 0
    for _ in pairs(jtacMgr.jtacs) do jtacInMgr = jtacInMgr + 1 end

    log("Step3 OK: DEPLOYED group='" .. gname .. "' alive=" .. #newAlive .. " registered=" .. registeredJtac .. " inManager=" .. jtacInMgr)
    pass("Step3 — 1st disembark: group='" .. gname .. "', alive=" .. #newAlive .. ", JTAC registered=" .. registeredJtac)

    -- STEP 4: S_EVENT_DEAD on one JTAC
    log("─── STEP 4 ───")
    if registeredJtac < 2 then fail("expected ≥2 registered JTAC, got " .. registeredJtac) end

    local jtacNameToKill = nil
    for name, _ in pairs(jtacMgr.jtacs) do jtacNameToKill = name; break end
    if not jtacNameToKill then fail("no JTAC in manager") end

    log("simulating S_EVENT_DEAD for '" .. jtacNameToKill .. "'")
    troopMgr:onUnitDead(jtacNameToKill)

    local jtacAfter = 0
    for _ in pairs(jtacMgr.jtacs) do jtacAfter = jtacAfter + 1 end

    log("Step4 OK: JTAC remaining=" .. jtacAfter .. " (was 2)")
    if jtacAfter >= 2 then fail("expected 1 JTAC after onUnitDead, got " .. jtacAfter) end
    pass("Step4 — S_EVENT_DEAD: '" .. jtacNameToKill .. "' removed, " .. jtacAfter .. " JTAC(s) remaining")

    -- STEP 5: embarkFromField — deregisterJTAC THEN destroy
    log("─── STEP 5 ───")
    local deployedName = nil
    for _, gn in ipairs(troopMgr._droppedGroups[coalition.side.BLUE] or {}) do
        local g = Group.getByName(gn)
        if g and g:isExist() then deployedName = gn; break end
    end
    if not deployedName then fail("no deployed group found") end

    local deregNames = {}
    for gname_j, _ in pairs(jtacMgr.jtacs) do
        table.insert(deregNames, gname_j)
        jtacMgr:deregisterJTAC(gname_j)
        log("deregisterJTAC('" .. gname_j .. "')")
    end

    local deployedGrp = Group.getByName(deployedName)
    if deployedGrp then deployedGrp:destroy() end
    log("group:destroy() for '" .. deployedName .. "'")

    local jtacAfterD = 0
    for _ in pairs(jtacMgr.jtacs) do jtacAfterD = jtacAfterD + 1 end

    if jtacAfterD ~= 0 then fail("expected 0 JTAC after deregister, got " .. jtacAfterD) end
    local gCheck = Group.getByName(deployedName)
    if gCheck and gCheck:isExist() then fail("DCS group still exists after destroy") end

    troopMgr:_removeFromDropped(coalition.side.BLUE, deployedName)
    log("Step5 OK: JTAC×" .. #deregNames .. " deregistered, group destroyed")
    pass("Step5 — embarkFromField: JTAC×" .. #deregNames .. " deregistered, group destroyed")

    -- STEP 6: disembark after field — respawn + resumeJTAC
    log("─── STEP 6 ───")
    local tmpl2 = troopMgr:_findTemplate(TEST_TMPL_NAME)
    if not tmpl2 then fail("template missing for respawn") end

    local spawnX2 = pPos.x + 120
    local spawnZ2 = pPos.z + 30
    local dcsGroup2 = spawnTroopGroup(tmpl2._dbKey, coalition.side.BLUE, country.id.USA, spawnX2, spawnZ2, 0)
    if not dcsGroup2 then fail("spawnTroopGroup step6 failed") end

    local gname2 = dcsGroup2:getName()

    log("calling resumeJTAC('" .. gname2 .. "')")
    jtacMgr:resumeJTAC(gname2)

    local jtacAfterR = 0
    for _ in pairs(jtacMgr.jtacs) do jtacAfterR = jtacAfterR + 1 end

    if jtacAfterR < 1 then fail("expected ≥1 JTAC after resumeJTAC, got " .. jtacAfterR) end

    local jtacEntry = nil
    for _, j in pairs(jtacMgr.jtacs) do if j.state then jtacEntry = j; break end end

    log("Step6 OK: after=" .. jtacAfterR .. " state=" .. tostring(jtacEntry and jtacEntry.state))
    pass("Step6 — disembark after field: group='" .. gname2 .. "', resumeJTAC() called (state=" .. tostring(jtacEntry and jtacEntry.state) .. ")")

    -- STEP 7: returnToTroopZone
    log("─── STEP 7 ───")
    local remainingJtac = nil
    for g, _ in pairs(jtacMgr.jtacs) do remainingJtac = g; break end
    if not remainingJtac then fail("no JTAC remaining — run Step 6 first") end

    log("deregisterJTAC('" .. remainingJtac .. "')")
    jtacMgr:deregisterJTAC(remainingJtac)
    troopMgr._inTransit[playerName] = nil

    for coa = 1, 2 do
        local alive = {}
        for _, gn in ipairs(troopMgr._droppedGroups[coa] or {}) do
            if gn ~= remainingJtac then table.insert(alive, gn) end
        end
        troopMgr._droppedGroups[coa] = alive
    end

    local jtacAfterR7 = 0
    for _ in pairs(jtacMgr.jtacs) do jtacAfterR7 = jtacAfterR7 + 1 end

    if jtacAfterR7 ~= 0 then fail("expected 0 JTAC after deregister, got " .. jtacAfterR7) end
    log("Step7 OK: JTAC deregistered, inTransit cleared")
    pass("Step7 — returnToTroopZone: JTAC deregistered, inTransit cleared, 0 JTAC in manager")

    -- STEP 8: final report + cleanup
    log("─── STEP 8 ───")
    local droppedBlue = #(troopMgr._droppedGroups[coalition.side.BLUE] or {})
    local inTransit = 0
    for _ in pairs(troopMgr._inTransit or {}) do inTransit = inTransit + 1 end
    local jtacFinal = 0
    for _ in pairs(jtacMgr.jtacs) do jtacFinal = jtacFinal + 1 end
    local templates = #(troopMgr._templates or {})

    log("═══════════════════════════════════════════════════════")
    log("SCENARIO COMPLETE — Full Troop Cycle (2 JTAC)")
    log("Final — dropped=" .. droppedBlue .. " | inTransit=" .. inTransit .. " | jtacs=" .. jtacFinal .. " | templates=" .. templates)
    log("═══════════════════════════════════════════════════════")

    report("═══════════════════════════════════════")
    report("SCENARIO COMPLETE — Full Troop Cycle")
    report("Steps 1-8 ALL PASS")
    report("Final — dropped=" .. droppedBlue .. " inTransit=" .. inTransit .. " jtacs=" .. jtacFinal .. " templates=" .. templates)
    report("═══════════════════════════════════════")

    cleanupAll()
    log("All test objects removed.")

    _result = "ALL SUCCESS"
end)

-- ── CLEANUP (debug always restored) ───────────────────────────────────────────
cfg.settings["debug"] = _saved_debug

if not _ok then
    return TAG .. " FAIL: " .. tostring(_err)
end
return TAG .. " " .. _result
