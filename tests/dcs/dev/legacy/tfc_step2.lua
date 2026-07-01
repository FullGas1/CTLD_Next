ctld.debug = true
local LOG = (ctld and ctld.path or "") .. "CTLD.log"
local f = io.open(LOG, "a")
f:write("[TFC] standalone Step2 executing\n")
f:flush()
f:close()

local TAG = "[tfc_s2]"
local STEP_N = "_TFC_STEP"
local TEST_TMPL_NAME = "Test2JTAC"

local playerUnit = nil
do local u = coalition.getPlayers(coalition.side.BLUE) or {} if #u > 0 then playerUnit = u[1] end end
if not playerUnit or not playerUnit:isExist() then trigger.action.outText("[TFC] ABORT: no BLUE player", 30); return end
local playerName = playerUnit:getName()
local pPos = playerUnit:getPoint()

local troopMgr = CTLDTroopManager.getInstance()
local tmpl = troopMgr:_findTemplate(TEST_TMPL_NAME)
if not tmpl then trigger.action.outText("[TFC] FAIL: template not found", 30); return end

local grp = CTLDTroopGroup:new({
    templateKey  = tmpl._dbKey,
    templateName = tmpl.name,
    unitTotal    = tmpl.total,
    weight       = tmpl.total * 124,
    hasJtac      = tmpl.hasJtac,
    coalitionId  = coalition.side.BLUE,
    countryId    = country.id.USA,
    state        = "TRZ_LOADED",
})

local aliveUnits, jtacUnits, unitIndex = {}, {}, 0
for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
    local n = tmpl[role] or 0
    for i = 1, n do
        unitIndex = unitIndex + 1
        local unitName = string.format("%s_u%d", tmpl.name, unitIndex)
        if role == "jtac" then jtacUnits[unitName] = true else aliveUnits[unitName] = unitIndex end
    end
end

grp._aliveUnits = aliveUnits
grp._jtacUnits  = jtacUnits
grp.dcsGroup    = nil
troopMgr._inTransit[playerName] = grp

f = io.open(LOG, "a")
f:write("[TFC] Step2: TRZ_LOADED alive=" .. #aliveUnits .. " jtac=" .. #jtacUnits .. "\n")
f:close()

trigger.action.outText("[TFC] Step 2 PASS - TRZ_LOADED (inf=" .. #aliveUnits .. " jtac=" .. #jtacUnits .. "). Re-inject Step 3.", 30)
_G[STEP_N] = 3
return "Step2 done"