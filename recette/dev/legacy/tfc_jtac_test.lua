env.info("[tfc_jtac_test] START")
ctld.debug = true

local playerUnit = nil
do local u = coalition.getPlayers(coalition.side.BLUE) or {} if #u > 0 and u[1]:isExist() then playerUnit = u[1] end end
if not playerUnit then trigger.action.outText("[JTAC_TEST] no player", 30); return end
local pPos = playerUnit:getPoint()

local jtacMgr = CTLDJTACManager.get()
env.info("[tfc_jtac_test] jtacMgr=" .. tostring(jtacMgr ~= nil))

-- Spawn a simple group
local units = {}
for i = 1, 3 do
    units[i] = { name = "Test_jtac" .. i, type = "Infantry AK", x = pPos.x + i * 3, y = pPos.z, heading = 0, skill = "Average" }
end
local gDef = { name = "TFC_JTAC_Test_Grp", task = "Ground Nothing", units = units }
local g = coalition.addGroup(country.id.USA, Group.Category.GROUND, gDef)
if not g then trigger.action.outText("[JTAC_TEST] addGroup FAILED", 30); return end

local gname = g:getName()
local gunits = g:getUnits()
env.info("[tfc_jtac_test] group created: " .. gname .. " units=" .. #gunits)

-- Check Group.getByName
local g2 = Group.getByName(gname)
env.info("[tfc_jtac_test] Group.getByName('" .. gname .. "')=" .. tostring(g2 ~= nil))
if g2 then env.info("[tfc_jtac_test] group isExist=" .. tostring(g2:isExist())) end

-- Try spawnJTAC
local jtac = jtacMgr:spawnJTAC(gname, "JTAC", coalition.side.BLUE)
env.info("[tfc_jtac_test] spawnJTAC('" .. gname .. "') → " .. tostring(jtac ~= nil))
trigger.action.outText("[JTAC_TEST] spawnJTAC('" .. gname .. "') result=" .. tostring(jtac ~= nil), 30)

if jtac then
    env.info("[tfc_jtac_test] jtac.groupName=" .. tostring(jtac.groupName))
    local jtacInMgr = 0
    for k, v in pairs(jtacMgr.jtacs) do jtacInMgr = jtacInMgr + 1; env.info("[tfc_jtac_test] jtacs['" .. k .. "']=" .. tostring(v ~= nil)) end
    trigger.action.outText("[JTAC_TEST] jtacs in manager=" .. jtacInMgr, 30)
end

-- cleanup
if g and g:isExist() then g:destroy() end
env.info("[tfc_jtac_test] END")
return "test_done"