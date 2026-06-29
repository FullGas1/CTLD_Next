---@diagnostic disable
-- =============================================================================
-- scenario_ai_transport_visual.lua  [INTERACTIVE]
-- Feature N — AI transport auto-pickup visual verification
--
-- Spawns an AI UH-1H helicopter ("CTLD_AI_TEST") inside TRZ pickup zone pz1,
-- adds it to transportPilotNames, and lets _checkAIStatus fire automatically
-- (2s loop). After a few seconds, troops should appear around the helicopter.
--
-- Protocol:
--   Step 1 — Spawn AI heli at zone pz1 center + register in transportPilotNames
--   Step 2 — (inject ~5s later) Verify hasTroops + show cargo manifest on screen
--   Step 3 — Cleanup (disembark, destroy heli, restore transportPilotNames)
--
-- Pre-requisites:
--   - BLUE player in mission (for country ID)
--   - TRZ zone named "pz1" configured as pickup (pickup=true), coalition BLUE
--   - CTLD fully initialised + enable_debug.lua injected
--   - allowRandomAiTeamPickups: any value (scenario works with both)
-- =============================================================================

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

local TAG    = "[AI-VIS]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_AI_VIS_STEP"

local AI_UNIT_NAME  = "CTLD_AI_TEST_u1"
local AI_GROUP_NAME = "CTLD_AI_TEST"
local TRZ_NAME      = "pz1"   -- pickup zone in the test mission

local function log(msg)   ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end
local function pass(msg)   report("[PASS] " .. msg) end
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

-- ── Cleanup helper ────────────────────────────────────────────────────────────
local function cleanup()
    -- Restore transportPilotNames
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT_NAME then table.remove(names, i) end
    end
    -- Unload troops if any remain
    local unit = Unit.getByName(AI_UNIT_NAME)
    if unit and unit:isExist() then
        local ok, tm = pcall(CTLDTroopManager.getInstance)
        if ok and tm and tm:hasTroops(AI_UNIT_NAME) then
            tm:disembarkAll(unit)
        end
    end
    -- Destroy AI group
    local grp = Group.getByName(AI_GROUP_NAME)
    if grp and grp:isExist() then grp:destroy() end
    log("cleanup done")
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────

_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Spawn AI helicopter at pz1 center, register in transportPilotNames
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    -- Get player country (BLUE)
    local blueUnits = coalition.getPlayers(coalition.side.BLUE) or {}
    local blueCountry = (blueUnits[1] and blueUnits[1]:isExist())
        and blueUnits[1]:getCountry()
        or country.id.USA

    -- Find TRZ pz1 center
    local zm   = CTLDZoneManager.getInstance()
    local zone = zm._troopZones[TRZ_NAME]
    if not zone then fail("TRZ zone '" .. TRZ_NAME .. "' not found") end

    local zpt = zone.center   -- {x, y, z} world coords
    check("AI-VIS.1.1", "TRZ pz1 found and active", zone.active,
        "active=" .. tostring(zone.active))

    -- Destroy leftover from previous run
    local oldGrp = Group.getByName(AI_GROUP_NAME)
    if oldGrp and oldGrp:isExist() then oldGrp:destroy() end

    -- Spawn AI UH-1H inside the zone (on ground, heading north)
    local grp = coalition.addGroup(blueCountry, Group.Category.HELICOPTER, {
        name       = AI_GROUP_NAME,
        task       = "Transport",
        start_time = 0,
        groupId    = math.random(87000, 87999),
        x          = zpt.x,
        y          = zpt.z,   -- DCS addGroup uses (x,y) = (world-x, world-z)
        units = {{
            name          = AI_UNIT_NAME,
            type          = "UH-1H",
            x             = zpt.x,
            y             = zpt.z,
            alt           = zpt.y,
            heading       = 0,
            skill         = "Excellent",
            unitId        = math.random(88000, 88999),
            playerCanDrive = false,
        }},
    })
    check("AI-VIS.1.2", "AI heli group spawned", grp ~= nil)

    -- Register in transportPilotNames
    local names = cfg.settings["transportPilotNames"] or {}
    local already = false
    for _, n in ipairs(names) do if n == AI_UNIT_NAME then already = true; break end end
    if not already then table.insert(names, AI_UNIT_NAME) end
    cfg.settings["transportPilotNames"] = names

    -- Rebuild _aiTeams so the new template list applies (in case it changed)
    CTLDCoreManager.getInstance():_initAITransports()

    -- Verify the unit exists and has no player
    local aiUnit = Unit.getByName(AI_UNIT_NAME)
    check("AI-VIS.1.3", "AI unit found by name", aiUnit ~= nil)
    if aiUnit then
        check("AI-VIS.1.4", "unit has no player (AI confirmed)",
            aiUnit:getPlayerName() == nil,
            "playerName=" .. tostring(aiUnit:getPlayerName()))
    end

    report("⬛ AI heli spawned at " .. TRZ_NAME .. " — wait 5s then re-inject for Step 2")
    report("⬛ Watch for troops appearing on F10 map around the helicopter")

    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Verify troops loaded automatically by _checkAIStatus loop
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local ok, tm = pcall(CTLDTroopManager.getInstance)
    if not ok then fail("CTLDTroopManager unavailable") end

    local hasTr = tm:hasTroops(AI_UNIT_NAME)
    check("AI-VIS.2.1", "AI heli has troops onboard after auto-pickup",
        hasTr, "hasTroops=" .. tostring(hasTr))

    if hasTr then
        local list = tm:getInTransit(AI_UNIT_NAME) or {}
        local total = 0
        local names = {}
        for _, grp in ipairs(list) do
            total = total + (grp.unitTotal or 0)
            table.insert(names, grp.templateName or "?")
        end
        report("📦 Cargo manifest: " .. total .. " soldier(s) — groups: " .. table.concat(names, ", "))
        report("✅ Auto-pickup confirmed — re-inject for Step 3 (cleanup)")
    else
        report("⚠️  No troops yet — the loop may not have fired or the heli is not in zone.")
        report("   Check CTLD.log for INIT-A / _checkAIStatus entries.")
        report("   If newly spawned, wait 2 more seconds and re-inject Step 2.")
    end

    _G[STEP_N] = hasTr and 3 or 2   -- stay at step 2 if not loaded yet
    _result = hasTr and "step=2 SUCCESS" or "step=2 WAITING"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    cleanup()

    report("Cleanup done — AI heli destroyed, transportPilotNames restored")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    cfg.settings["debug"] = _saved_debug
    -- best-effort cleanup on error
    pcall(cleanup)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
        :gsub("WAITING", "WAITING (" .. _ms .. "ms)")
