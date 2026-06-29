---@diagnostic disable
-- =============================================================================
-- diag_slot_switch_events.lua
-- Diagnose slot-switch detection by CTLD
--
-- Installs a raw DCS world event handler that logs ALL player-related events
-- to screen and CTLD.log.  After each event, dumps a snapshot of:
--   - CTLDPlayerManager._players  (tracked units)
--   - ctld.MenuManager menus      (menus in memory)
--
-- Objective: observe which DCS events fire (or don't) when a player leaves a
-- slot and takes another one, and verify that CTLD:
--   1. Detects the departure  (LEAVE_UNIT or scan)
--   2. Removes the old F10 menu
--   3. Detects the arrival    (ENTER_UNIT or scan)
--   4. Builds a new F10 menu for the new unit
--
-- Re-inject this script to STOP the handler and print a final state dump.
--
-- Prerequisites:
--   - CTLD_Next.lua injected (>= 3 s before this script)
--   - At least one player in a slot
-- =============================================================================

local TAG    = "[DIAG-SLOT]"
local KEY    = "_diag_slot_switch_handler"
local SEQ    = "_diag_slot_switch_seq"
local DUR    = 20   -- screen text duration (seconds)

-- ── Helpers ──────────────────────────────────────────────────────────────────

--- Return a short readable description of a DCS Unit (or nil-safe).
local function unitInfo(u)
    if not u then return "nil" end
    local ok, name     = pcall(function() return u:getName() end)
    local ok2, pname   = pcall(function() return u:getPlayerName() end)
    local ok3, tname   = pcall(function() return u:getTypeName() end)
    local ok4, grp     = pcall(function() return u:getGroup() end)
    local gname = (ok4 and grp) and grp:getName() or "?"
    return string.format("unit='%s' player='%s' type='%s' grp='%s'",
        ok  and tostring(name)  or "?",
        ok2 and tostring(pname) or "?",
        ok3 and tostring(tname) or "?",
        gname)
end

--- Readable event id → name mapping (most common ones).
local EVENT_NAMES = {
    [world.event.S_EVENT_SHOT]               = "SHOT",
    [world.event.S_EVENT_HIT]                = "HIT",
    [world.event.S_EVENT_TAKEOFF]            = "TAKEOFF",
    [world.event.S_EVENT_LAND]               = "LAND",
    [world.event.S_EVENT_CRASH]              = "CRASH",
    [world.event.S_EVENT_EJECTION]           = "EJECTION",
    [world.event.S_EVENT_REFUELING]          = "REFUELING",
    [world.event.S_EVENT_DEAD]               = "DEAD",
    [world.event.S_EVENT_PILOT_DEAD]         = "PILOT_DEAD",
    [world.event.S_EVENT_BASE_CAPTURED]      = "BASE_CAPTURED",
    [world.event.S_EVENT_MISSION_START]      = "MISSION_START",
    [world.event.S_EVENT_MISSION_END]        = "MISSION_END",
    [world.event.S_EVENT_BIRTH]              = "BIRTH",
    [world.event.S_EVENT_PLAYER_ENTER_UNIT]  = "PLAYER_ENTER_UNIT",
    [world.event.S_EVENT_PLAYER_LEAVE_UNIT]  = "PLAYER_LEAVE_UNIT",
    [world.event.S_EVENT_KILL]               = "KILL",
}

--- Dump current CTLD player+menu state as a multi-line string.
local function dumpState()
    local lines = {}

    -- CTLDPlayerManager._players
    local pm = CTLDPlayerManager.getInstance()
    local playerCount = 0
    for unitName, pObj in pairs(pm._players or {}) do
        playerCount = playerCount + 1
        lines[#lines+1] = string.format(
            "  PLAYER tracked: unit='%s' type='%s' grpId=%s",
            unitName, tostring(pObj.typeName), tostring(pObj.groupId))
    end
    if playerCount == 0 then
        lines[#lines+1] = "  PLAYERS: (none tracked)"
    end

    -- ctld.MenuManager.menus
    local mm = ctld.MenuManager:getInstance()
    local menuCount = 0
    for groupId, menu in pairs(mm.menus or {}) do
        menuCount = menuCount + 1
        local childCount = menu.children and #menu.children or 0
        lines[#lines+1] = string.format(
            "  MENU grpId=%s children=%d", tostring(groupId), childCount)
    end
    if menuCount == 0 then
        lines[#lines+1] = "  MENUS: (none)"
    end

    return table.concat(lines, "\n")
end

-- ── STOP if already running ───────────────────────────────────────────────────
if _G[KEY] then
    world.removeEventHandler(_G[KEY])
    _G[KEY]  = nil
    _G[SEQ]  = nil

    local msg = TAG .. " STOPPED — final state:\n" .. dumpState()
    trigger.action.outText(msg, DUR)
    ctld.utils.log("INFO", TAG .. " handler removed. Final state:\n" .. dumpState())
    return TAG .. " STOPPED"
end

-- ── Initial state snapshot ────────────────────────────────────────────────────
_G[SEQ] = 0

local initState = TAG .. " STARTED — initial state:\n" .. dumpState()
trigger.action.outText(initState, DUR)
ctld.utils.log("INFO", initState)

-- ── Event handler installation ────────────────────────────────────────────────
local handler = {}

function handler:onEvent(event)
    -- Determine event name
    local eid   = event.id or 0
    local ename = EVENT_NAMES[eid] or ("EVENT_" .. tostring(eid))

    -- Filter: only log events that involve a player unit, plus ENTER/LEAVE always
    local isPlayerEvent = (
        eid == world.event.S_EVENT_PLAYER_ENTER_UNIT or
        eid == world.event.S_EVENT_PLAYER_LEAVE_UNIT
    )

    local initiator = event.initiator
    local pname = nil
    if initiator then
        local ok, p = pcall(function() return initiator:getPlayerName() end)
        if ok and p then
            pname = p
            isPlayerEvent = true
        end
    end

    if not isPlayerEvent then return end

    _G[SEQ] = (_G[SEQ] or 0) + 1
    local seq = _G[SEQ]

    local uinfo = unitInfo(initiator)

    local stateDump = dumpState()

    local msg = string.format(
        TAG .. " [#%d] EVENT: %s\n  initiator: %s\nState after:\n%s",
        seq, ename, uinfo, stateDump)

    trigger.action.outText(msg, DUR)
    ctld.utils.log("INFO", msg)
end

world.addEventHandler(handler)
_G[KEY] = handler

trigger.action.outText(
    TAG .. " Handler installed.\n" ..
    "Now: leave your slot and take another one.\n" ..
    "Events and CTLD state will be logged to screen + CTLD.log.\n" ..
    "Re-inject this script to STOP.", DUR)

return TAG .. " STARTED — watching player events"
