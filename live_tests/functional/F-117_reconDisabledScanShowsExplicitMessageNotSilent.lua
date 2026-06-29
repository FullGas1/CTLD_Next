-- F-117 — RECON disabled: scan() shows explicit message (not silent)
-- Verify: when reconEnabled=false, scan() emits outTextForGroup with "reconEnabled" keyword.

local results = {}
local function assert_eq(label, got, exp)
    if got == exp then
        results[#results+1] = "PASS " .. label
    else
        results[#results+1] = string.format("FAIL %s  got=%s  exp=%s", label, tostring(got), tostring(exp))
    end
end
local function assert_true(label, cond)
    assert_eq(label, not not cond, true)
end

local rmgr = CTLDReconManager.getInstance()
local players = coalition.getPlayers(coalition.side.BLUE) or {}
local pu = players[1]
if not pu then return "ABORT: no BLUE player" end
local playerName = pu:getName()

local cfg = CTLDConfig.get().settings

-- ── mock outTextForGroup to capture message ───────────────────────────────────
local _captured = nil
local _orig_otfg = trigger.action.outTextForGroup
trigger.action.outTextForGroup = function(gid, msg, dur)
    _captured = msg
    _orig_otfg(gid, msg, dur)
end

-- ── U-01: reconEnabled=false → message contains "reconEnabled" ───────────────
local _origEnabled = cfg["reconEnabled"]
cfg["reconEnabled"] = false
pcall(function() rmgr:scan(pu, playerName) end)
assert_true("U-01 message emitted",          _captured ~= nil)
assert_true("U-01 message mentions config",  _captured and _captured:find("reconEnabled"))

-- ── U-02: reconEnabled=true → no disabled message ───────────────────────────
_captured = nil
cfg["reconEnabled"] = true
cfg["reconMinAltitude"] = 0   -- bypass altitude check
pcall(function() rmgr:scan(pu, playerName) end)
-- Message may be nil or be the "no layers" message — must NOT be the disabled message.
local isDisabledMsg = _captured and _captured:find("reconEnabled")
assert_eq("U-02 no disabled message when enabled", isDisabledMsg, nil)

-- ── restore ───────────────────────────────────────────────────────────────────
cfg["reconEnabled"]    = _origEnabled
trigger.action.outTextForGroup = _orig_otfg

local pass = 0; local fail = 0
for _, r in ipairs(results) do
    env.info("[F-117] " .. r)
    if r:sub(1,4) == "PASS" then pass = pass+1 else fail = fail+1 end
end

local summary = string.format("F-117: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(summary, 15)
env.info("[F-117] " .. summary)
return summary
