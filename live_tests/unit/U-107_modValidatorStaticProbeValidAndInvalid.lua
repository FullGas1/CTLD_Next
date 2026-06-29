---@diagnostic disable
-- U-107: CTLDModValidator — _probeStatic valid and invalid type detection
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

-- Fresh singleton
CTLDModValidator._instance = nil
local mv = CTLDModValidator.getInstance()
mv._probePos = { x = -356437, z = 617000 }  -- near Batumi

local _origLog = ctld.utils.log
ctld.utils.log = function() end

-- C1: valid STATIC type ("outpost_road" — standard DCS Fortifications static)
mv:_probeStatic("outpost_road", "Fortifications", {})
chk("C1 valid STATIC (outpost_road) → cache=true", mv._cache["S:outpost_road"] == true)

-- C2: invalid STATIC type (fabricated name)
mv:_probeStatic("CTLD_INVALID_STATIC_XYZ_9999", "Fortifications", {})
chk("C2 invalid STATIC → cache=false", mv._cache["S:CTLD_INVALID_STATIC_XYZ_9999"] == false)

local idx_after_probes = mv._probeIdx

-- C3: cache hit valid
local r3 = mv:_probeStatic("outpost_road", "Fortifications", {})
chk("C3 cache hit valid → true, no new probe", r3 == true and mv._probeIdx == idx_after_probes)

-- C4: cache hit invalid
local r4 = mv:_probeStatic("CTLD_INVALID_STATIC_XYZ_9999", "Fortifications", {})
chk("C4 cache hit invalid → false, no new probe", r4 == false and mv._probeIdx == idx_after_probes)

ctld.utils.log = _origLog

local msg = string.format("U-107 STATIC probe: %d PASS / %d FAIL\n%s",
    _t.pass, _t.fail, table.concat(_t.msgs, "\n"))
trigger.action.outText(msg, 30)
env.info("[U-107] " .. msg:gsub("\n", " | "))
return msg
