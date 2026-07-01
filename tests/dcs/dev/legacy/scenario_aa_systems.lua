---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_aa_systems.lua
-- Injectable test scenario — deploy AA systems (short/mid/long) for BLUE and RED.
--
-- BLUE systems (Batumi area, 2km east, 1km apart on X):
--   short : M1097 Avenger   (standard multi-crate, single DCS unit)
--   mid   : NASAMS          (AA template: LN + Radar + CP)
--   long  : Patriot         (AA template: LN + Radar + ECS)
--
-- RED systems (Kobuleti area, 2km east, 1km apart on X):
--   short : 9K33 Osa        (standard multi-crate, single DCS unit)
--   mid   : KUB             (AA template: LN + Radar)
--   long  : S-300           (AA template: TEL-C + TR + SR1 + SR2 + C2)
--
-- Unpack flows:
--   "standard" : spawnCrate × N + unpackCrate × N + _spawnUnpacked
--   "aa"       : spawnCrate × N + tryUnpackOrRepair via per-system proxy unit
--
-- CTLDCrateAssemblyManager._computeOrigin: origin = 100m ahead of proxy unit.
-- Each "aa" system spawns a proxy 100m SOUTH of its crate position (heading=0 → north).
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG   = "[AA]"
local START = os.date("%Y-%m-%d %H:%M:%S")

-- ── SPAWN POSITIONS ───────────────────────────────────────────────────────────
local BX0, BZ = -356437, 620211   -- Batumi + 2km east
local RX0, RZ = -317605, 638704   -- Kobuleti + 2km east
local SPACING  = 1000

local SYSTEMS = {
    {
        label    = "BLUE Short (Avenger)",
        flow     = "standard",
        coa      = coalition.side.BLUE,
        cty      = country.id.USA,
        cx       = BX0,             cz = BZ,
        weights  = { 1003.01, 1003.01, 1003.01 },
        unpackW  = 1003.01,
    },
    {
        label    = "BLUE Mid (NASAMS)",
        flow     = "aa",
        coa      = coalition.side.BLUE,
        cty      = country.id.USA,
        cx       = BX0 + SPACING,   cz = BZ,
        weights  = { 1004.11, 1004.12, 1004.13 },
        launcher = 1004.11,
    },
    {
        label    = "BLUE Long (Patriot)",
        flow     = "aa",
        coa      = coalition.side.BLUE,
        cty      = country.id.USA,
        cx       = BX0 + 2*SPACING, cz = BZ,
        weights  = { 1005.01, 1005.02, 1005.03 },
        launcher = 1005.01,
    },
    {
        label    = "RED Short (9K33 Osa)",
        flow     = "standard",
        coa      = coalition.side.RED,
        cty      = country.id.RUSSIA,
        cx       = RX0,             cz = RZ,
        weights  = { 1003.11, 1003.11, 1003.11 },
        unpackW  = 1003.11,
    },
    {
        label    = "RED Mid (KUB)",
        flow     = "aa",
        coa      = coalition.side.RED,
        cty      = country.id.RUSSIA,
        cx       = RX0 + SPACING,   cz = RZ,
        weights  = { 1004.21, 1004.22 },
        launcher = 1004.21,
    },
    {
        label    = "RED Long (S-300)",
        flow     = "aa",
        coa      = coalition.side.RED,
        cty      = country.id.RUSSIA,
        cx       = RX0 + 2*SPACING, cz = RZ,
        weights  = { 1005.11, 1005.12, 1005.13, 1005.14, 1005.15 },
        launcher = 1005.11,
    },
}

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

-- ── MAIN ──────────────────────────────────────────────────────────────────────
report("==== START " .. START .. " ====")

local _result = ""
local _ok, _err = pcall(function()

    local cmgr  = CTLDCrateManager.getInstance()
    local aaMgr = CTLDCrateAssemblyManager.getInstance()

    -- 0. cleanup
    for groupName, _ in pairs(aaMgr._completeSystems) do
        local grp = Group.getByName(groupName)
        if grp and grp:isExist() then grp:destroy() end
    end
    aaMgr._completeSystems = {}

    local removed = 0
    local aaCrateNames = {}
    for crateName, crate in pairs(cmgr.crates) do
        if crate.descriptor then
            local tmpl = aaMgr:getTemplateForUnit(crate.descriptor.unit)
            if tmpl or (crate.descriptor.weight and crate.descriptor.weight >= 1003) then
                table.insert(aaCrateNames, crateName)
            end
        end
    end
    for _, cn in ipairs(aaCrateNames) do cmgr:destroyCrate(cn); removed = removed + 1 end

    for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        for _, grp in ipairs(coalition.getGroups(coa)) do
            local gname = grp:getName()
            if (gname:find("^CTLD_UNP_") or gname:find("^CTLD_AA_PROXY_")) and grp:isExist() then
                grp:destroy(); removed = removed + 1
            end
        end
    end

    report(string.format("Step 0: cleanup done (%d removed)", removed))

    -- 1. spawn crates + per-system proxy units
    local spawnedSystems = {}

    for idx, sys in ipairs(SYSTEMS) do
        local allCrates     = {}
        local launcherCrate = nil
        local h = land.getHeight({ x = sys.cx, y = sys.cz })

        for i, w in ipairs(sys.weights) do
            local desc = cmgr:findDescriptorByWeight(w)
            if not desc then
                fail(string.format("no descriptor weight=%.2f for %s", w, sys.label))
            end
            local pos = { x = sys.cx, y = h, z = sys.cz + (i-1)*20 }
            local crate = cmgr:spawnCrate(desc, pos, sys.coa, "scenario_aa_systems",
                CTLDCrate.SPAWN_METHOD.MENU_CTLD, sys.cty)
            if not crate then
                fail(string.format("spawnCrate failed weight=%.2f %s", w, sys.label))
            end
            table.insert(allCrates, crate)
            if sys.launcher and desc.weight == sys.launcher then launcherCrate = crate end
            if sys.unpackW  and desc.weight == sys.unpackW  then launcherCrate = crate end
        end

        local proxyName = nil
        if sys.flow == "aa" then
            proxyName = string.format("CTLD_AA_PROXY_%d", idx)
            local ep = Group.getByName(proxyName)
            if ep and ep:isExist() then ep:destroy() end
            local ph = land.getHeight({ x = sys.cx - 100, y = sys.cz })
            coalition.addGroup(sys.cty, Group.Category.GROUND, {
                id = ctld.utils.getNextUniqId(), name = proxyName,
                task = "Ground Nothing", start_time = 0,
                units = {{ id = ctld.utils.getNextUniqId(), name = proxyName .. "-1",
                           type = "Ural-375", x = sys.cx - 100, y = sys.cz,
                           heading = 0, skill = "Average", playerCanDrive = false }},
                route = { points = {{ x = sys.cx - 100, y = sys.cz,
                                      type = "Turning Point", action = "Off Road",
                                      speed = 0, alt = ph }}},
            })
        end

        table.insert(spawnedSystems, {
            label         = sys.label,
            flow          = sys.flow,
            coa           = sys.coa,
            cty           = sys.cty,
            cx            = sys.cx,
            cz            = sys.cz,
            allCrates     = allCrates,
            launcherCrate = launcherCrate,
            unpackDesc    = sys.unpackW and cmgr:findDescriptorByWeight(sys.unpackW) or nil,
            proxyName     = proxyName,
        })
        report(string.format("Step 1: %d crate(s) spawned for %s", #allCrates, sys.label))
    end

    -- 2. unpack (T+3s — DCS statics + proxies registered)
    local function _doUnpack(sys)
        if sys.flow == "standard" then
            if not sys.launcherCrate or not sys.unpackDesc then
                report("SKIP standard " .. sys.label .. " — missing crate/desc"); return
            end
            local pos = { x = sys.cx, y = land.getHeight({x=sys.cx, y=sys.cz}), z = sys.cz }
            for _, c in ipairs(sys.allCrates) do cmgr:unpackCrate(c.crateName, nil) end
            cmgr:_spawnUnpacked(sys.unpackDesc, pos, sys.coa, sys.cty)
            report(string.format("Step 2: standard unpack done for %s", sys.label))
            return
        end

        if not sys.launcherCrate then
            report("SKIP AA " .. sys.label .. " — no launcher crate"); return
        end

        local proxyGrp  = sys.proxyName and Group.getByName(sys.proxyName)
        local proxyUnit = proxyGrp and proxyGrp:getUnit(1)
        if not proxyUnit then
            report("SKIP AA " .. sys.label .. " — proxy not found: " .. tostring(sys.proxyName))
            return
        end

        local ok = aaMgr:tryUnpackOrRepair(proxyUnit, sys.launcherCrate, cmgr.crates, 500)

        if proxyGrp and proxyGrp:isExist() then proxyGrp:destroy() end

        if ok then
            report(string.format("Step 2: AA unpack triggered for %s", sys.label))
        else
            report(string.format("WARN: tryUnpackOrRepair false for %s", sys.label))
        end
    end

    timer.scheduleFunction(function()
        for _, sys in ipairs(spawnedSystems) do _doUnpack(sys) end
    end, nil, timer.getTime() + 3)

    -- T+20s: VERIFY + screen message
    timer.scheduleFunction(function()
        local lines = {}
        local blueCount, redCount = 0, 0

        for groupName, entry in pairs(aaMgr._completeSystems) do
            local grp = Group.getByName(groupName)
            if grp and grp:isExist() then
                local coa  = grp:getCoalition()
                local n    = #grp:getUnits()
                local u1   = grp:getUnit(1)
                local p    = u1 and u1:getPoint()
                local sysN = entry.template and entry.template.name or groupName
                lines[#lines+1] = string.format("%s | %s | %d units @ (%.0f,%.0f)",
                    coa == 2 and "BLUE" or "RED", sysN, n, p and p.x or 0, p and p.z or 0)
                if coa == 2 then blueCount = blueCount + 1 else redCount = redCount + 1 end
            end
        end

        for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
            for _, grp in ipairs(coalition.getGroups(coa)) do
                local gname = grp:getName()
                if gname:find("^CTLD_UNP_") and grp:isExist() then
                    local n  = #grp:getUnits()
                    local u1 = grp:getUnit(1)
                    local p  = u1 and u1:getPoint()
                    local tp = u1 and u1:getTypeName() or "?"
                    lines[#lines+1] = string.format("%s | %s | %d units @ (%.0f,%.0f)",
                        coa == 2 and "BLUE" or "RED", tp, n, p and p.x or 0, p and p.z or 0)
                    if coa == 2 then blueCount = blueCount + 1 else redCount = redCount + 1 end
                end
            end
        end

        table.sort(lines)
        local summary = string.format("VERIFY T+20s: %d BLUE, %d RED systems\n%s",
            blueCount, redCount, table.concat(lines, "\n"))
        report(summary)

        trigger.action.outText(
            "=== AA SYSTEMS ON MAP ===\n" ..
            table.concat(lines, "\n") ..
            string.format("\n\nBLUE near Batumi  (%.0f, %.0f)", BX0, BZ) ..
            string.format("\nRED  near Kobuleti (%.0f, %.0f)", RX0, RZ), 90)
    end, nil, timer.getTime() + 20)

    _result = string.format("started | 6 systems | BLUE@(%.0f,%.0f) RED@(%.0f,%.0f)",
        BX0, BZ, RX0, RZ)
end)

-- ── CLEANUP (debug always restored) ───────────────────────────────────────────
cfg.settings["debug"] = _saved_debug

if not _ok then
    return TAG .. " FAIL: " .. tostring(_err)
end
return TAG .. " " .. _result
