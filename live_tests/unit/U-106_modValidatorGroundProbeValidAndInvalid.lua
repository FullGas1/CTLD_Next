---@diagnostic disable
-- U-106: CTLDModValidator — _probeGround valid and invalid type detection
-- Checks: C1 valid type cached true, C2 invalid cached false, C3/C4 cache hits (no re-spawn)
-- Requires: DCS active, CTLD_Next injected

local _t = { pass=0, fail=0, msgs={} }
local function chk(label, cond)
    if cond then
        _t.pass = _t.pass + 1; _t.msgs[#_t.msgs+1] = "[PASS] " .. label
    else
        _t.fail = _t.fail + 1; _t.msgs[#_t.msgs+1] = "[FAIL] " .. label
    end
end

-- Fresh singleton (clear any previous run cache)
CTLDModValidator._instance = nil
local mv = CTLDModValidator.getInstance()
mv._probePos = { x = -356437, z = 617000 }  -- near Batumi

-- Suppress log output during probe (avoid noise in CTLD.log)
local _origLog = ctld.utils.log
ctld.utils.log = function() end

-- C1: valid GROUND type (BRDM-2 — standard DCS unit)
mv:_probeGround("BRDM-2")
chk("C1 valid GROUND (BRDM-2) → cache=true", mv._cache["G:BRDM-2"] == true)

-- C2: invalid GROUND type (fabricated name)
mv:_probeGround("CTLD_INVALID_UNIT_XYZ_9999")
chk("C2 invalid GROUND → cache=false", mv._cache["G:CTLD_INVALID_UNIT_XYZ_9999"] == false)

local idx_after_probes = mv._probeIdx  -- should be 2

-- C3: valid result is served from cache (no new probe spawn)
local r3 = mv:_probeGround("BRDM-2")
chk("C3 cache hit valid → true, no new probe", r3 == true and mv._probeIdx == idx_after_probes)

-- C4: invalid result is served from cache (no new probe spawn)
local r4 = mv:_probeGround("CTLD_INVALID_UNIT_XYZ_9999")
chk("C4 cache hit invalid → false, no new probe", r4 == false and mv._probeIdx == idx_after_probes)

ctld.utils.log = _origLog

local msg = string.format("U-106 GROUND probe: %d PASS / %d FAIL\n%s",
    _t.pass, _t.fail, table.concat(_t.msgs, "\n"))
trigger.action.outText(msg, 30)
env.info("[U-106] " .. msg:gsub("\n", " | "))
return msg
