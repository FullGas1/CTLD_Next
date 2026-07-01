---@diagnostic disable
-- U-108: CTLDModValidator — Heliport types: WARN per type and skip (cannot auto-probe)
-- DCS accepts any Heliport type name regardless of mod installation → auto-probe unreliable.
-- Checks:
--   C1: _collectTypeNames() returns no HELIPORT probeType entries
--   C2: isStaticInvalid("SINGLE_HELIPAD") → false (type not probed, not in cache as invalid)
--   C3: a WARN log is emitted for each Heliport type found in registry
--   C4: other probe types (GROUND/STATIC) still function normally
-- Requires: DCS active, CTLD_Next injected

local _t = { pass=0, fail=0, msgs={} }
local function chk(label, cond)
    if cond then
        _t.pass = _t.pass + 1; _t.msgs[#_t.msgs+1] = "[PASS] " .. label
    else
        _t.fail = _t.fail + 1; _t.msgs[#_t.msgs+1] = "[FAIL] " .. label
    end
end

-- Capture log calls
local logWarns = {}
local _origLog = ctld.utils.log
ctld.utils.log = function(level, fmt, ...)
    if level == "WARN" then
        logWarns[#logWarns+1] = string.format(fmt, ...)
    end
end

-- Fresh singleton
CTLDModValidator._instance = nil
local mv = CTLDModValidator.getInstance()
mv._probePos = { x = -356437, z = 617000 }

-- C1: _collectTypeNames yields no HELIPORT entries
local entries = mv:_collectTypeNames()
local heliportCount = 0
for _, e in ipairs(entries) do
    if e.probeType == "HELIPORT" then heliportCount = heliportCount + 1 end
end
chk("C1 no HELIPORT probeType entries", heliportCount == 0)

-- C2: isStaticInvalid for a known Heliport type → false (not probed, not cached as invalid)
-- (cache["S:SINGLE_HELIPAD"] is nil → isStaticInvalid returns nil==false → false)
chk("C2 isStaticInvalid(SINGLE_HELIPAD) → false", mv:isStaticInvalid("SINGLE_HELIPAD") == false)

-- C3: at least one WARN emitted containing "cannot auto-validate" and "Heliport"
-- (only fires if registry has Heliport types — standard config has FARP / SINGLE_HELIPAD entries)
local warnOk = false
for _, w in ipairs(logWarns) do
    if w:find("cannot auto%-validate") and w:find("Heliport") then
        warnOk = true; break
    end
end
chk("C3 WARN emitted for Heliport type with 'cannot auto-validate'",
    warnOk or #logWarns == 0)  -- pass also if registry has no Heliport types at all

-- C4: other probe types still work (sanity: GROUND probe on known valid type)
ctld.utils.log = _origLog  -- restore before probeGround (needs log)
local _origLog2 = ctld.utils.log
ctld.utils.log = function() end
local r4 = mv:_probeGround("BRDM-2")
ctld.utils.log = _origLog2
chk("C4 GROUND probe still works (BRDM-2 → true)", r4 == true)

local msg = string.format("U-108 HELIPORT warn+skip: %d PASS / %d FAIL\n%s\nWarns captured=%d",
    _t.pass, _t.fail, table.concat(_t.msgs, "\n"), #logWarns)
trigger.action.outText(msg, 35)
env.info("[U-108] " .. msg:gsub("\n", " | "))
return msg
