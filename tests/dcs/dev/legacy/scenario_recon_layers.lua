---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_recon_layers.lua
-- Interactive RECON layer test — inject once per layer.
-- Each injection: cleanup previous → spawn target unit → scan → report detection.
-- Re-inject when ready to move to the next layer.
--
-- State persisted across injections via global _RECON_LAYER_IDX (integer 1–7).
-- Injection TOTAL+2 resets counter and destroys all test units.
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG = "[RECON]"

-- ── HELPER: restore debug before returning ────────────────────────────────────
local function _ret(s)
    cfg.settings["debug"] = _saved_debug
    return s
end

-- ── LAYER DEFINITIONS ────────────────────────────────────────────────────────
local BATUMI = { x = -356437, z = 618211 }
local NM1    = 1852

local LAYERS = {
    {
        layerId = "infantry",
        label   = "Infantry",
        cat     = Group.Category.GROUND,
        grpName = "RECON_TEST_infantry",
        uName   = "RECON_TEST_inf_1",
        uType   = "Soldier AK",
        dx = -200, dz = -30,
    },
    {
        layerId = "ground_vehicles",
        label   = "Ground Vehicles",
        cat     = Group.Category.GROUND,
        grpName = "RECON_TEST_vehicle",
        uName   = "RECON_TEST_veh_1",
        uType   = "BMP-2",
        dx = -200, dz = 30,
    },
    {
        layerId = "air_defense",
        label   = "Air Defense (AA)",
        cat     = Group.Category.GROUND,
        grpName = "RECON_TEST_aa",
        uName   = "RECON_TEST_aa_1",
        uType   = "ZU-23 Emplacement Closed",
        dx = -250, dz = 0,
    },
    {
        layerId  = "aircraft",
        label    = "Aircraft",
        cat      = Group.Category.AIRPLANE,
        grpName  = "RECON_TEST_ac",
        uName    = "RECON_TEST_ac_1",
        uType    = "Su-25",
        useOrbit = true,
        spawnAlt = 500,
        color    = { 0.95, 0.77, 0.06, 0.8 },
    },
    {
        layerId  = "helicopters",
        label      = "Helicopters",
        cat        = Group.Category.HELICOPTER,
        grpName    = "RECON_TEST_helo",
        uName      = "RECON_TEST_helo_1",
        uType      = "Mi-8MT",
        useOrbit   = true,
        usePlayer  = true,
        orbitSide  = 500,
        spawnAlt   = 300,
        color      = { 0.90, 0.49, 0.13, 0.8 },
    },
    {
        layerId   = "ships",
        label     = "Ships",
        cat       = Group.Category.SHIP,
        grpName   = "RECON_TEST_ship",
        uName     = "RECON_TEST_ship_1",
        uType     = "Speedboat",
        useAbs    = true,
        absX      = BATUMI.x + 556,
        absZ      = BATUMI.z - 3500,
    },
}

local TOTAL  = #LAYERS
local RUSSIA = country.id.RUSSIA

-- ── HELPERS ───────────────────────────────────────────────────────────────────
local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end
local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 40)
    log(msg)
end

local function destroyGroup(name)
    local g = Group.getByName(name)
    if g and g:isExist() then g:destroy() end
end

local function destroyAll()
    for _, lay in ipairs(LAYERS) do destroyGroup(lay.grpName) end
end

local function destroyBlueGroundUnits()
    local grps = coalition.getGroups(coalition.side.BLUE, Group.Category.GROUND) or {}
    for _, g in ipairs(grps) do
        if g and g:isExist() then
            g:destroy()
            log("destroyed BLUE ground group: " .. g:getName())
        end
    end
end

local function nextId() return ctld.utils.getNextUniqId() end

local _routeMarkId = 90000
local function nextRouteMarkId()
    _routeMarkId = _routeMarkId + 1
    return _routeMarkId
end

local function drawOrbitRoute(cx, cz, alt, side, color)
    local wps = {
        { x = cx,        z = cz + side },
        { x = cx - side, z = cz - side },
        { x = cx + side, z = cz - side },
    }
    for i = 1, 3 do
        local j = (i % 3) + 1
        trigger.action.lineToAll(-1, nextRouteMarkId(),
            { x = wps[i].x, y = alt, z = wps[i].z },
            { x = wps[j].x, y = alt, z = wps[j].z },
            color, 2, true, "")
    end
end

local function loopingTriangleRoute(cx, cz, alt_m, side, speed)
    side  = side  or NM1
    speed = speed or 100
    local n   = 3
    local wps = {
        { x = cx,        y = cz + side },
        { x = cx - side, y = cz - side },
        { x = cx + side, y = cz - side },
    }
    local pts = {}
    for i = 1, n do
        pts[i] = {
            x            = wps[i].x,
            y            = wps[i].y,
            alt          = alt_m,
            alt_type     = "BARO",
            speed        = speed,
            speed_locked = true,
            type         = "Turning Point",
            action       = "Turning Point",
            ETA          = 0,
            ETA_locked   = false,
            task         = { id = "ComboTask", params = { tasks = {} } },
        }
    end
    pts[n].task = {
        id     = "ComboTask",
        params = { tasks = { [1] = {
            enabled = true, auto = false,
            id      = "WrappedAction", number = 1,
            params  = { action = {
                id     = "SwitchWaypoint",
                params = { goToWaypointIndex = 1, fromWaypointIndex = n },
            }},
        }}}
    }
    return { points = pts }
end

local function spawnUnit(lay, pPos)
    local ok, err

    if lay.useOrbit then
        local spawnX = lay.usePlayer and pPos.x or BATUMI.x
        local spawnZ = lay.usePlayer and pPos.z or BATUMI.z
        local side   = lay.orbitSide or NM1
        local alt    = lay.spawnAlt or 500
        ok, err = pcall(function()
            coalition.addGroup(RUSSIA, lay.cat, {
                id = nextId(), name = lay.grpName,
                task = "Nothing", start_time = 0,
                units = {{
                    id = nextId(), name = lay.uName, type = lay.uType,
                    x = spawnX, y = spawnZ, heading = 0,
                    skill = "Average", playerCanDrive = false, alt = alt,
                }},
                route = loopingTriangleRoute(spawnX, spawnZ, alt, side),
            })
        end)
        if ok then
            local color = lay.color or { 1.0, 0.5, 0.0, 0.8 }
            drawOrbitRoute(spawnX, spawnZ, alt, side, color)
        end

    elseif lay.useAbs then
        local px, pz = lay.absX, lay.absZ
        ok, err = pcall(function()
            coalition.addGroup(RUSSIA, lay.cat, {
                id = nextId(), name = lay.grpName,
                task = "Nothing", start_time = 0,
                units = {{
                    id = nextId(), name = lay.uName, type = lay.uType,
                    x = px, y = pz, heading = 0,
                    skill = "Average", playerCanDrive = false,
                }},
                route = { points = {{
                    x = px, y = pz, type = "Turning Point",
                    action = "Turning Point", speed = 5, alt = 0,
                }}},
            })
        end)

    else
        local px = pPos.x + lay.dx
        local pz = pPos.z + lay.dz
        local py = land.getHeight({ x = px, y = pz })
        ok, err = pcall(function()
            coalition.addGroup(RUSSIA, lay.cat, {
                id = nextId(), name = lay.grpName,
                task = "Ground Nothing", start_time = 0,
                units = {{
                    id = nextId(), name = lay.uName, type = lay.uType,
                    x = px, y = pz, heading = 0,
                    skill = "Average", playerCanDrive = false,
                }},
                route = { points = {{
                    x = px, y = pz, type = "Turning Point",
                    action = "Off Road", speed = 0, alt = py,
                }}},
            })
        end)
    end

    if not ok then return false, err end
    timer.scheduleFunction(function()
        local g = Group.getByName(lay.grpName)
        if g and g:isExist() then
            local ctrl = g:getController()
            ctrl:setOption(0, 4)
            ctrl:setOption(9, 0)
        end
    end, nil, timer.getTime() + 0.5)
    return true, nil
end

-- ── RESOLVE PLAYER ────────────────────────────────────────────────────────────
local playerUnit = nil
do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 then playerUnit = units[1] end
end

if not playerUnit or not playerUnit:isExist() then
    return _ret(TAG .. " ABORT: no BLUE player — occupy a slot first")
end

local playerName = playerUnit:getName()
local rmgr       = CTLDReconManager.getInstance()
local pPos       = playerUnit:getPoint()

-- Permanently enable RECON for the test session (no restore — intentional).
do
    local cfgS = CTLDConfig.get().settings
    cfgS["reconEnabled"]    = true
    cfgS["reconMinAltitude"] = 0
end

destroyBlueGroundUnits()

local function clearAllMarks()
    for i = 90001, 90030 do pcall(trigger.action.removeMark, i) end
    for _, s in pairs(rmgr._activeScans or {}) do
        if s and s.targets then
            for _, t in ipairs(s.targets) do
                if t.markId then
                    pcall(function() CTLDReconRenderer.removeIcon(t.markId) end)
                    t.markId = nil
                end
            end
        end
    end
end

local function cleanupScan(scan, key)
    if not scan then return end
    if scan.refreshTimer then
        pcall(timer.removeFunction, scan.refreshTimer)
        scan.refreshTimer = nil
    end
    pcall(function() rmgr:_removeAllMarks(scan) end)
    rmgr._activeScans[key] = nil
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_RECON_LAYER_IDX = _RECON_LAYER_IDX or 1

clearAllMarks()

-- Full reset (injection TOTAL+2)
if _RECON_LAYER_IDX > TOTAL + 1 then
    destroyAll()
    cleanupScan(rmgr._activeScans[playerName], playerName)
    local layers = rmgr:_getPlayerLayers(playerName)
    for _, l in ipairs(layers) do l.enabled = false end
    _RECON_LAYER_IDX = 1
    return _ret(TAG .. " RESET — all test units destroyed, layers OFF. Re-inject to start from layer 1.")
end

-- Sandbox phase (injection TOTAL+1)
if _RECON_LAYER_IDX == TOTAL + 1 then
    destroyAll()
    cleanupScan(rmgr._activeScans[playerName], playerName)

    local allLayers = rmgr:_getPlayerLayers(playerName)
    for _, l in ipairs(allLayers) do l.enabled = true end

    local spawnErrors = {}
    for _, lay in ipairs(LAYERS) do
        local ok, err = spawnUnit(lay, pPos)
        if not ok then spawnErrors[#spawnErrors + 1] = lay.layerId .. ": " .. tostring(err) end
    end

    report("=== SANDBOX MODE — all layers ON, all threats spawned ===")
    if #spawnErrors > 0 then
        report("  spawn errors: " .. table.concat(spawnErrors, ", "))
    end
    report("  Toggle layers via F10 RECON menu. Re-inject this script to RESET.")

    timer.scheduleFunction(function()
        local pu = playerUnit:isExist() and playerUnit or nil
        if not pu then return end
        local cfgS = CTLDConfig.get().settings
        local oRad = cfgS["reconSearchRadius"]
        cfgS["reconSearchRadius"] = 12000
        pcall(function() rmgr:scan(pu, playerName) end)
        cfgS["reconSearchRadius"] = oRad
        local s = rmgr._activeScans[playerName]
        report(string.format("  RECON started: %d targets detected", s and #s.targets or 0))
        if s then
            for _, t in ipairs(s.targets) do
                report(string.format("    [%s] %s dist=%.0fm", t.layer.layerId, t.unitType, t.distance or 0))
            end
        end
    end, nil, timer.getTime() + 2)

    _RECON_LAYER_IDX = TOTAL + 2
    return _ret(TAG .. " SANDBOX — all threats spawned, RECON starts in 2s. Toggle layers via F10. Re-inject to RESET.")
end

local current = LAYERS[_RECON_LAYER_IDX]

-- 1. Cleanup all test units + previous scan
destroyAll()
cleanupScan(rmgr._activeScans[playerName], playerName)

-- 2. Disable all layers, toggle only the current one ON
local allLayers = rmgr:_getPlayerLayers(playerName)
for _, l in ipairs(allLayers) do
    l.enabled = false
end
for _, l in ipairs(allLayers) do
    if l.layerId == current.layerId then l.enabled = true end
end

report(string.format("Layer %d/%d — toggle [%s] %s → ON  (all others OFF)",
    _RECON_LAYER_IDX, TOTAL, current.layerId, current.label))

-- 3. Spawn the target unit
local spawnOk, spawnErr = spawnUnit(current, pPos)
if not spawnOk then
    report("SPAWN FAIL: " .. tostring(spawnErr))
    return _ret(TAG .. " ERROR: spawn failed for " .. current.layerId)
end

if current.useOrbit then
    report(string.format("  spawned: %s '%s'  orbit 10nm around Batumi alt=%dm",
        current.uType, current.grpName, current.spawnAlt or 500))
elseif current.useAbs then
    report(string.format("  spawned: %s '%s'  abs pos x=%.0f z=%.0f",
        current.uType, current.grpName, current.absX, current.absZ))
else
    report(string.format("  spawned: %s '%s'  offset=(%.0f, %.0f)",
        current.uType, current.grpName, current.dx, current.dz))
end

-- 4. Scan after delay (air units need time to appear in DCS unit list)
local needsWideRadius = (current.useOrbit and not current.usePlayer) or current.useAbs

timer.scheduleFunction(function()
    local pu = playerUnit:isExist() and playerUnit or nil
    if not pu then report("SCAN SKIP: player gone"); return end

    local cfgS = CTLDConfig.get().settings
    local origRadius = cfgS["reconSearchRadius"]
    if needsWideRadius then cfgS["reconSearchRadius"] = 8000 end
    local ok2, err2 = pcall(function() rmgr:scan(pu, playerName) end)
    cfgS["reconSearchRadius"] = origRadius
    if not ok2 then report("SCAN ERROR: " .. tostring(err2)); return end

    local scan = rmgr._activeScans[playerName]
    local n = scan and #scan.targets or 0

    if n == 0 then
        report("  SCAN: 0 targets — unit may be out of LOS or wrong DCS attribute. Check F10 map manually.")
    else
        for _, tgt in ipairs(scan.targets) do
            report(string.format("  DETECTED [%s] %s  markId=%s  dist=%.0fm",
                tgt.layer.layerId, tgt.unitType, tostring(tgt.markId), tgt.distance or 0))
        end
        report(string.format("  Layer [%s] PASS — icon visible on F10 map", current.layerId))
    end

    report(string.format(">>> Re-inject when ready for layer %d/%d [%s]",
        _RECON_LAYER_IDX + 1, TOTAL,
        (_RECON_LAYER_IDX < TOTAL) and LAYERS[_RECON_LAYER_IDX + 1].label or "RESET"))
end, nil, timer.getTime() + (needsWideRadius and 3 or 1))

-- advance counter
_RECON_LAYER_IDX = _RECON_LAYER_IDX + 1

local scanDelay = needsWideRadius and "3s" or "1s"
return _ret(string.format(TAG .. " Layer %d/%d [%s] — spawning %s — scan in %s",
    _RECON_LAYER_IDX - 1, TOTAL, current.label, current.uType, scanDelay))
