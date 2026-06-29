ctld.debug = true
local LOG = (ctld and ctld.path or "") .. "CTLD.log"
local function rawLog(msg)
    local f = io.open(LOG, "a")
    if f then f:write(msg .. "\n"); f:close() end
end

local TAG = "[tfc_s3]"
local STEP_N = "_TFC_STEP"
local TEST_TMPL_NAME = "Test2JTAC"

rawLog(TAG .. " starting")

local playerUnit = nil
do local u = coalition.getPlayers(coalition.side.BLUE) or {} if #u > 0 then playerUnit = u[1] end end
if not playerUnit or not playerUnit:isExist() then rawLog(TAG .. " ABORT: no BLUE player"); trigger.action.outText("[TFC] ABORT: no BLUE player", 30); return end
local playerName = playerUnit:getName()
local pPos = playerUnit:getPoint()

local troopMgr = CTLDTroopManager.getInstance()
local jtacMgr = CTLDJTACManager.get()
if not jtacMgr then rawLog(TAG .. " FAIL: no JTAC manager"); trigger.action.outText("[TFC] FAIL: no JTAC manager", 30); return end

local grp = troopMgr._inTransit[playerName]
if not grp then rawLog(TAG .. " FAIL: no TRZ_LOADED group in _inTransit - run Step 2 first"); trigger.action.outText("[TFC] FAIL: no TRZ_LOADED group - run Step 2 first", 30); return end

local tmpl = troopMgr:_findTemplate(TEST_TMPL_NAME)
if not tmpl then rawLog(TAG .. " FAIL: template missing"); trigger.action.outText("[TFC] FAIL: template missing", 30); return end

local spawnX = pPos.x + 80
local spawnZ = pPos.z + 30

local idx = 0
local units = {}
for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
    local n = tmpl[role] or 0
    for i = 1, n do
        idx = idx + 1
        local unitType = (role == "jtac") and "Infantry AK" or "Infantry AK"
        units[idx] = {
            name = string.format("TFC_u%d", idx),
            type = unitType,
            x = spawnX, y = spawnZ,
            heading = 0,
            skill = "Average",
        }
    end
end

local grpDef = {
    name = string.format("TFC_Grp_%d", ctld.utils.getNextUniqId()),
    task = "Ground Nothing",
    units = units,
}

local dcsGroup = coalition.addGroup(country.id.USA, Group.Category.GROUND, grpDef)
if not dcsGroup then rawLog(TAG .. " FAIL: coalition.addGroup failed"); trigger.action.outText("[TFC] FAIL: coalition.addGroup failed", 30); return end

local gname = dcsGroup:getName()
grp.dcsGroup = dcsGroup
grp.state = "DEPLOYED"

local dcsUnits = dcsGroup:getUnits()
local newAlive, newJtac = {}, {}
local unitIdx = 0

for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
    local n = tmpl[role] or 0
    for i = 1, n do
        if unitIdx + 1 <= #dcsUnits then
            local dcsUnit = dcsUnits[unitIdx + 1]
            local unitName = dcsUnit:getName()
            if role == "jtac" then
                newJtac[unitName] = true
                rawLog(TAG .. " calling spawnJTAC for '" .. unitName .. "'")
                local ok = jtacMgr:spawnJTAC(unitName, "JTAC", coalition.side.BLUE)
                rawLog(TAG .. " spawnJTAC result=" .. tostring(ok))
            else
                newAlive[unitName] = dcsUnit
            end
        end
        unitIdx = unitIdx + 1
    end
end

grp._aliveUnits = newAlive
grp._jtacUnits  = newJtac
troopMgr._inTransit[playerName] = nil
table.insert(troopMgr._droppedGroups[coalition.side.BLUE], gname)

local jtacCount = 0
for _ in pairs(jtacMgr.jtacs or {}) do jtacCount = jtacCount + 1 end

rawLog(TAG .. " DEPLOYED group='" .. gname .. "' alive=" .. #newAlive .. " jtac=" .. #newJtac .. " manager=" .. jtacCount)
trigger.action.outText("[TFC] Step 3 PASS - DEPLOYED (alive=" .. #newAlive .. " jtac=" .. #newJtac .. ", in manager=" .. jtacCount .. "). Re-inject Step 4.", 30)

_G[STEP_N] = 4
return "Step3 done"