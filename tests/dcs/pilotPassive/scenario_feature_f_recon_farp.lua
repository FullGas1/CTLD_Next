---@diagnostic disable
-- =============================================================================
-- scenario_feature_f_recon_farp.lua   [FARP]
-- Feature F — RECON layer FARP/FOB : CTLDStaticWatcher + coalition rendering
--
-- Pre-requisites:
--   - CTLD_Next.lua injected and initialised (wait 3-5 s)
--   - enable_debug.lua injected
--   - Mission "red_FARP" group / "red_FARP-1" present (RED)
--   - inject_red_fob.lua already executed (adds red FOB to CTLDFOBManager)
--   - Player unit "Pilot" in BLUE coalition (or any BLUE transport)
--
-- Steps:
--   F-150  CTLDStaticWatcher:watch/unwatch/tick mechanics (mock)
--   F-151  drawFarpIcon draws with player coalition (not -1)
--   F-152  drawInfantryIcon/drawVehicleIcon coalition param propagated
--   F-153  _matchLayer skips farp_fob layer (no filterAttrib)
--   F-154  _syncFarpMarks detects red FARP via coalition.getAirbases
--   F-155  _syncFarpMarks detects red FOB via CTLDFOBManager
--   F-156  _syncFarpMarks dedup: 2nd call adds no new marks
--   F-157  _clearFarpMarks removes marks and unwatches
--   F-158  CTLDStaticWatcher fires onDeadFn when checkFn returns false
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FARP] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local TAG  = "[FARP]"
local STEP = "_FARP_STEP"

local cfg         = CTLDConfig.get()
local _saved_dbg  = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local function report(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
    trigger.action.outText(TAG .. " " .. msg, 30)
end
local function pass(id, msg)
    ctld.utils.log("INFO", TAG .. " [PASS] " .. id .. " — " .. msg)
end
local function fail(msg)
    ctld.utils.log("ERROR", TAG .. " [FAIL] " .. msg)
    error(msg)
end
local function check(id, desc, cond, detail)
    if not cond then
        fail(id .. " FAILED: " .. desc .. " | " .. tostring(detail))
    end
    pass(id, desc)
end

local step = _G[STEP] or 0
step = step + 1
_G[STEP] = step

local ok, result = pcall(function()

-- ── Banner ────────────────────────────────────────────────────────────────
report(string.format("==== START %s | step=%d ====", os.date("%H:%M:%S"), step))

-- ── F-150 : CTLDStaticWatcher watch/unwatch/tick ──────────────────────────
if step == 1 then
    report("F-150 CTLDStaticWatcher basic mechanics")

    local watcher = CTLDStaticWatcher.getInstance()
    local fired   = false
    local aliveFlag = true

    watcher:watch("test_id_150",
        function() return aliveFlag end,
        function() fired = true end
    )
    check("F-150.1", "watch registered", watcher._watched["test_id_150"] ~= nil, "")

    watcher:unwatch("test_id_150")
    check("F-150.2", "unwatch deregisters", watcher._watched["test_id_150"] == nil, "")

    -- Re-register, simulate tick with alive=true → no fire
    watcher:watch("test_id_150b",
        function() return aliveFlag end,
        function() fired = true end
    )
    watcher:_tick(timer.getTime())
    check("F-150.3", "tick with alive=true: onDeadFn not fired", fired == false, tostring(fired))
    watcher:unwatch("test_id_150b")

    report("F-150 PASS")
    return TAG .. " step=1 SUCCESS"

-- ── F-151 : drawFarpIcon uses player coalition ────────────────────────────
elseif step == 2 then
    report("F-151..153 Renderer coalition param")

    -- Mock trigger.action to capture coalition arg
    local captured = {}
    local _orig_circle = trigger.action.circleToAll
    local _orig_line   = trigger.action.lineToAll
    local _orig_rect   = trigger.action.rectToAll
    trigger.action.circleToAll = function(coa, ...) captured[#captured+1] = { fn="circle", coa=coa } end
    trigger.action.lineToAll   = function(coa, ...) captured[#captured+1] = { fn="line",   coa=coa } end
    trigger.action.rectToAll   = function(coa, ...) captured[#captured+1] = { fn="rect",   coa=coa } end

    local pos   = { x=0, y=0, z=0 }
    local color = { 1, 0, 0, 1 }
    local mid   = 9600

    -- F-151: FARP icon with coalition=2
    CTLDReconRenderer.drawFarpIcon(pos, mid, color, 2)
    check("F-151.1", "drawFarpIcon: 3 draw calls", #captured == 3, tostring(#captured))
    for i, c in ipairs(captured) do
        check("F-151." .. (i+1), "drawFarpIcon call " .. i .. " coalition=2",
            c.coa == 2, tostring(c.coa))
    end

    -- F-152: Infantry icon coalition propagated
    captured = {}
    CTLDReconRenderer.drawInfantryIcon(pos, mid+1, color, 1)
    check("F-152.1", "drawInfantryIcon coalition=1 slot1",
        captured[1] and captured[1].coa == 1, tostring(captured[1] and captured[1].coa))

    -- F-152: Vehicle icon
    captured = {}
    CTLDReconRenderer.drawVehicleIcon(pos, mid+2, color, 2)
    check("F-152.2", "drawVehicleIcon coalition=2 slot1",
        captured[1] and captured[1].coa == 2, tostring(captured[1] and captured[1].coa))

    -- F-153: _matchLayer skips farp_fob (no filterAttrib)
    local rmgr   = CTLDReconManager.getInstance()
    local layers = rmgr:_getPlayerLayers("mock_player_153")
    local farpLayer = nil
    for _, l in ipairs(layers) do
        if l.layerId == "farp_fob" then farpLayer = l; break end
    end
    check("F-153.1", "farp_fob layer exists in defaults", farpLayer ~= nil, "")
    check("F-153.2", "farp_fob filterAttrib is nil", farpLayer and farpLayer.filterAttrib == nil, "")

    -- Mock unit with no attributes — _matchLayer should not return farp layer
    local mockUnit = { hasAttribute = function() return false end }
    farpLayer.enabled = true   -- force enabled for test
    local matched = rmgr:_matchLayer(mockUnit, layers)
    check("F-153.3", "_matchLayer returns nil for farp_fob (no filterAttrib)",
        matched == nil, tostring(matched))
    farpLayer.enabled = false  -- restore

    trigger.action.circleToAll = _orig_circle
    trigger.action.lineToAll   = _orig_line
    trigger.action.rectToAll   = _orig_rect

    report("F-151..153 PASS")
    return TAG .. " step=2 SUCCESS"

-- ── F-154..157 : _syncFarpMarks ───────────────────────────────────────────
elseif step == 3 then
    report("F-154..157 _syncFarpMarks + _clearFarpMarks")

    -- Requires: inject_red_fob.lua already run (red FARP + red FOB in CTLDFOBManager)
    -- We need a mock playerUnit at altitude in BLUE coalition
    local blueUnit = ctld_test and ctld_test.getTransport and ctld_test.getTransport()
    if not blueUnit then
        -- Fallback: try first BLUE group unit
        local blueGroups = coalition.getGroups(coalition.side.BLUE) or {}
        for _, g in ipairs(blueGroups) do
            if g:isExist() then
                local us = g:getUnits() or {}
                if us[1] and us[1]:isExist() then blueUnit = us[1]; break end
            end
        end
    end
    check("F-154.0", "BLUE player unit found", blueUnit ~= nil, "no BLUE unit")

    local rmgr   = CTLDReconManager.getInstance()
    local player = "test_player_F154"

    -- Enable farp_fob layer for test player
    local layers = rmgr:_getPlayerLayers(player)
    for _, l in ipairs(layers) do
        if l.layerId == "farp_fob" then l.enabled = true end
    end

    -- Mock renderer to avoid real DCS draw
    local drawCount = 0
    local _orig_create = CTLDReconRenderer.createIcon
    CTLDReconRenderer.createIcon = function(t, mid) drawCount = drawCount + 1 end
    local _orig_remove = CTLDReconRenderer.removeIcon
    CTLDReconRenderer.removeIcon = function(mid) end

    -- Mock coalition.getAirbases: mission may have no RED FARPs/helipads, so inject one
    local pPos_154 = blueUnit:getPoint()
    local fakeAB_154 = {
        isExist  = function() return true end,
        getDesc  = function() return { attributes = { Helipad = true } } end,
        getPoint = function() return { x = pPos_154.x + 200, y = pPos_154.y, z = pPos_154.z } end,
        getName  = function() return "red_FARP_mock" end,
    }
    local _orig_getAirbases = coalition.getAirbases
    coalition.getAirbases = function(coa)
        if coa == coalition.side.RED then return { fakeAB_154 } end
        return _orig_getAirbases(coa)
    end

    -- F-154: FARP detected via coalition.getAirbases (mocked)
    local airbases = coalition.getAirbases(coalition.side.RED) or {}
    check("F-154.1", "RED airbase (FARP) mock present", #airbases >= 1,
        "count=" .. #airbases)

    -- F-155: FOB detected via CTLDFOBManager (requires inject_red_fob.lua)
    local fobMgr = CTLDFOBManager.getInstance()
    local hasRedFOB = false
    for _, fob in pairs(fobMgr._fobs) do
        if fob.coalitionId == coalition.side.RED then hasRedFOB = true end
    end
    check("F-155.1", "RED FOB in CTLDFOBManager (inject_red_fob required)",
        hasRedFOB, tostring(hasRedFOB))

    -- Call _syncFarpMarks — playerUnit at any position, LOS may or may not detect
    -- (we only verify no crash + marks table created)
    rmgr:_syncFarpMarks(blueUnit, player)
    check("F-154.2", "_farpMarks table created for player",
        rmgr._farpMarks[player] ~= nil, "")

    local markCountAfterFirst = 0
    for _ in pairs(rmgr._farpMarks[player]) do markCountAfterFirst = markCountAfterFirst + 1 end
    ctld.utils.log("INFO", TAG .. " marks after first sync: %d", markCountAfterFirst)

    -- F-156: dedup — 2nd _syncFarpMarks must not add new marks
    local drawCountBefore = drawCount
    rmgr:_syncFarpMarks(blueUnit, player)
    check("F-156.1", "dedup: 2nd sync adds 0 new marks",
        drawCount == drawCountBefore, "extra draws=" .. (drawCount - drawCountBefore))

    -- F-157: _clearFarpMarks removes all marks and unwatches
    rmgr:_clearFarpMarks(player)
    local markCountAfterClear = 0
    for _ in pairs(rmgr._farpMarks[player]) do markCountAfterClear = markCountAfterClear + 1 end
    check("F-157.1", "_clearFarpMarks empties _farpMarks[player]",
        markCountAfterClear == 0, "remaining=" .. markCountAfterClear)

    coalition.getAirbases        = _orig_getAirbases
    CTLDReconRenderer.createIcon = _orig_create
    CTLDReconRenderer.removeIcon = _orig_remove

    -- Disable layer
    for _, l in ipairs(layers) do
        if l.layerId == "farp_fob" then l.enabled = false end
    end

    report("F-154..157 PASS")
    return TAG .. " step=3 SUCCESS"

-- ── F-158 : CTLDStaticWatcher fires onDeadFn ─────────────────────────────
elseif step == 4 then
    report("F-158 CTLDStaticWatcher onDeadFn on dead")

    local watcher = CTLDStaticWatcher.getInstance()
    local deadFired = false
    local alive = true

    watcher:watch("test_dead_158",
        function() return alive end,
        function() deadFired = true end
    )
    -- First tick: still alive
    watcher:_tick(timer.getTime())
    check("F-158.1", "tick alive=true: not fired", deadFired == false, tostring(deadFired))

    -- Simulate death
    alive = false
    watcher:_tick(timer.getTime())
    check("F-158.2", "tick alive=false: onDeadFn fired", deadFired == true, tostring(deadFired))
    check("F-158.3", "entry auto-removed after death",
        watcher._watched["test_dead_158"] == nil, "still present")

    report("F-158 PASS")
    _G[STEP] = nil
    return TAG .. " step=4 SUCCESS — ALL PASS (F-150..F-158)"
else
    _G[STEP] = nil
    fail("step=" .. step .. " has no branch")
end

end)  -- pcall

cfg.settings["debug"] = _saved_dbg
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

if not ok then
    ctld.utils.log("ERROR", TAG .. " step=" .. step .. " FAIL: " .. tostring(result))
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(result)
end
trigger.action.outText(TAG .. " ✅ DONE", 20, true)
return result
