---@diagnostic disable
-- U-108: CTLDModValidator — _probeHeliport via getDesc().life detection
-- DCS substitue visuellement les types inconnus par SINGLE_HELIPAD mais life==0 trahit la substitution.
-- C1: valid HELIPORT (SINGLE_HELIPAD) → cache=true (life>0)
-- C2: invalid HELIPORT → cache=false (life==0)
-- C3: cache hit valid → no new probe
-- C4: cache hit invalid → no new probe
-- Note: ghost spawné 800km est, hors zone visible — vérifier F10 si souhaité

local _t = { pass=0, fail=0, msgs={} }
local function chk(label, cond)
    if cond then _t.pass=_t.pass+1; _t.msgs[#_t.msgs+1]="[PASS] "..label
    else _t.fail=_t.fail+1; _t.msgs[#_t.msgs+1]="[FAIL] "..label end
end

CTLDModValidator._instance = nil
local mv = CTLDModValidator.getInstance()
mv._probePos = { x = -356437, z = 617000 }

local _origLog = ctld.utils.log
ctld.utils.log = function() end

mv:_probeHeliport("SINGLE_HELIPAD", "Heliports", {})
chk("C1 valid HELIPORT (SINGLE_HELIPAD) → cache=true", mv._cache["S:SINGLE_HELIPAD"] == true)

mv:_probeHeliport("CTLD_INVALID_HELIPAD_XYZ_9999", "Heliports", {})
chk("C2 invalid HELIPORT → cache=false", mv._cache["S:CTLD_INVALID_HELIPAD_XYZ_9999"] == false)

local idx_snap = mv._probeIdx

local r3 = mv:_probeHeliport("SINGLE_HELIPAD", "Heliports", {})
chk("C3 cache hit valid → true, no new probe", r3==true and mv._probeIdx==idx_snap)

local r4 = mv:_probeHeliport("CTLD_INVALID_HELIPAD_XYZ_9999", "Heliports", {})
chk("C4 cache hit invalid → false, no new probe", r4==false and mv._probeIdx==idx_snap)

ctld.utils.log = _origLog

local msg = string.format("U-108 HELIPORT life-check: %d PASS / %d FAIL\n%s",
    _t.pass, _t.fail, table.concat(_t.msgs, "\n"))
trigger.action.outText(msg, 35)
env.info("[U-108] " .. msg:gsub("\n", " | "))
return msg
