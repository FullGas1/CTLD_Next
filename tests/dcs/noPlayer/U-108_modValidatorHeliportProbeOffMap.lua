---@diagnostic disable
-- U-108: CTLDModValidator — _probeHeliport valid and invalid, off-map ghost check
-- Checks:
--   C1: valid HELIPORT type (SINGLE_HELIPAD) → cache=true
--   C2: invalid HELIPORT type → cache=false
--   C3: ghost off-map (world.getAirbases count near Batumi unchanged vs before probe)
--   C4: cache hit valid → no new probe
-- Requires: DCS active, CTLD_Next injected
-- User check: verify F10 map — no FARP marker visible near Batumi / play area

local _t = { pass=0, fail=0, msgs={} }
local function chk(label, cond)
    if cond then
        _t.pass = _t.pass + 1; _t.msgs[#_t.msgs+1] = "[PASS] " .. label
    else
        _t.fail = _t.fail + 1; _t.msgs[#_t.msgs+1] = "[FAIL] " .. label
    end
end

-- Count airbases whose name starts with CTLD_MVP (probe artefacts)
local function countProbeAirbases()
    local n = 0
    for _, a in ipairs(world.getAirbases() or {}) do
        local ok, nm = pcall(function() return a:getName() end)
        if ok and nm and nm:find("CTLD_MVP", 1, true) then n = n + 1 end
    end
    return n
end

-- Fresh singleton
CTLDModValidator._instance = nil
local mv = CTLDModValidator.getInstance()
mv._probePos = { x = -356437, z = 617000 }  -- near Batumi

local _origLog = ctld.utils.log
ctld.utils.log = function() end

local before = countProbeAirbases()

-- C1: valid HELIPORT type (SINGLE_HELIPAD — standard DCS helipad)
mv:_probeHeliport("SINGLE_HELIPAD", "Heliports", {})
chk("C1 valid HELIPORT (SINGLE_HELIPAD) → cache=true", mv._cache["S:SINGLE_HELIPAD"] == true)

-- C2: invalid HELIPORT type (fabricated name)
mv:_probeHeliport("CTLD_INVALID_HELIPAD_XYZ_9999", "Heliports", {})
chk("C2 invalid HELIPORT → cache=false", mv._cache["S:CTLD_INVALID_HELIPAD_XYZ_9999"] == false)

local idx_after_probes = mv._probeIdx

-- C3: ghost(s) from valid probe exist in registry but only 1 was added (invalid → no spawn)
local after = countProbeAirbases()
chk("C3 exactly 1 ghost probe airbase added (off-map)", after - before == 1)

-- C4: cache hit valid → no new probe, count unchanged
local r4 = mv:_probeHeliport("SINGLE_HELIPAD", "Heliports", {})
chk("C4 cache hit → true, no new probe", r4 == true and mv._probeIdx == idx_after_probes and countProbeAirbases() == after)

ctld.utils.log = _origLog

local msg = string.format(
    "U-108 HELIPORT probe: %d PASS / %d FAIL\n%s\n[User] Verify F10: no FARP visible in play area",
    _t.pass, _t.fail, table.concat(_t.msgs, "\n"))
trigger.action.outText(msg, 40)
env.info("[U-108] " .. msg:gsub("\n", " | "))
return msg
