-- F-118 — RECON toggle-OFF: marks removed immediately even when no layers remain.
-- Verify: when scan() is called and prevScan exists, marks are removed BEFORE the
-- "no layers" early-return path — so toggling the last layer OFF clears the map instantly.

local results = {}
local function assert_eq(label, got, exp)
    if got == exp then
        results[#results+1] = "PASS " .. label
    else
        results[#results+1] = string.format("FAIL %s  got=%s  exp=%s", label, tostring(got), tostring(exp))
    end
end
local function assert_true(label, cond)   assert_eq(label, not not cond, true) end
local function assert_false(label, cond)  assert_eq(label, not not cond, false) end

local rmgr = CTLDReconManager.getInstance()
local players = coalition.getPlayers(coalition.side.BLUE) or {}
local pu = players[1]
if not pu then return "ABORT: no BLUE player" end
local playerName = pu:getName()
local cfg = CTLDConfig.get().settings

-- Save state
local _origEnabled  = cfg["reconEnabled"]
local _origMinAlt   = cfg["reconMinAltitude"]
local _origRadius   = cfg["reconSearchRadius"]

cfg["reconEnabled"]      = true
cfg["reconMinAltitude"]  = 0
cfg["reconSearchRadius"] = 100   -- tiny radius → 0 targets, but scan still runs

-- ── U-01: force an active scan into _activeScans with a fake mark entry ───────
-- We inject a fake scan directly rather than spawning a real unit.
-- This tests the cleanup path in isolation from LOS/unit detection.
local fakeMarkId = ctld.utils.getNextMarkId()
-- Draw a real mark so removeMark has something to act on.
trigger.action.circleToAll(-1, fakeMarkId * 10 + 1,
    { x = pu:getPoint().x, y = 0, z = pu:getPoint().z }, 5, {1,0,0,1}, {1,0,0,0.1}, 1, true, "F118")

local fakeScan = {
    playerUnit  = pu,
    coalition   = pu:getCoalition(),
    autoRefresh = false,
    refreshTimer = nil,
    layers      = {},
    targets     = {{
        markId   = fakeMarkId,
        unitType = "TEST",
        distance = 10,
        layer    = { layerId = "infantry", color = {1,0,0,1} },
        unit     = nil,
    }},
}
rmgr._activeScans[playerName] = fakeScan

assert_true("U-01 fake scan injected", rmgr._activeScans[playerName] ~= nil)
assert_eq("U-01 fake scan has 1 target", #rmgr._activeScans[playerName].targets, 1)

-- ── U-02: disable ALL layers so scan() would hit "no layers" early-return ─────
local allLayers = rmgr:_getPlayerLayers(playerName)
local savedEnabled = {}
for _, l in ipairs(allLayers) do
    savedEnabled[l.layerId] = l.enabled
    l.enabled = false
end

-- ── U-03: call scan() — must remove prevScan marks AND return early ───────────
local ok, err = pcall(function() rmgr:scan(pu, playerName) end)
assert_true("U-03 scan() no error", ok)

-- After scan(): _activeScans[playerName] must be nil (prevScan was cleaned up).
assert_eq("U-04 activeScans nil after all-OFF scan", rmgr._activeScans[playerName], nil)

-- ── U-05: the fake mark slot must be gone (removeMark was called) ────────────
-- We can't directly query DCS for mark existence, but we verify the target's markId
-- was part of the scan that got cleaned — indirect proof via _activeScans being nil.
-- (Direct visual check: orange "F118" circle must disappear immediately on F10 map.)
assert_true("U-05 cleanup occurred (scan entry nil)", rmgr._activeScans[playerName] == nil)

-- ── restore ───────────────────────────────────────────────────────────────────
for _, l in ipairs(allLayers) do
    l.enabled = savedEnabled[l.layerId] or false
end
cfg["reconEnabled"]     = _origEnabled
cfg["reconMinAltitude"] = _origMinAlt
cfg["reconSearchRadius"] = _origRadius

local pass = 0; local fail = 0
for _, r in ipairs(results) do
    env.info("[F-118] " .. r)
    if r:sub(1,4) == "PASS" then pass = pass+1 else fail = fail+1 end
end

local summary = string.format("F-118: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(summary, 15)
env.info("[F-118] " .. summary)
return summary
