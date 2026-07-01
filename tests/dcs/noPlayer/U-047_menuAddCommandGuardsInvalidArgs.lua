---@diagnostic disable
-- U-47 : ctld.Menu:addCommand — guards, invalid args
trigger.action.outText("U-47: addCommand guards + invalid args", 10)

local log = function(msg) env.info("[U-47] " .. msg) end
local pass, fail = 0, 0
local function ok(label, cond)
    if cond then pass = pass + 1; log("PASS " .. label)
    else fail = fail + 1; log("FAIL " .. label) end
end

missionCommands = missionCommands or { addSubMenuForGroup=function()end, addCommandForGroup=function()end, removeItemForGroup=function()end }
ctld = ctld or {}; ctld.tr=ctld.tr or function(k)return k end
ctld.logInfo=ctld.logInfo or function()end; ctld.logWarning=ctld.logWarning or function()end; ctld.logError=ctld.logError or function()end
Unit=Unit or {getByName=function()return nil end,getByID=function()return nil end}
coalition=coalition or {getGroups=function()return{}end}
ctld.MenuManager._instance = nil

local m = ctld.MenuManager:getInstance():createMenuForGroup(2)
m:addSubMenu({}, "CTLD Commands")
m:addSubMenu({"CTLD Commands"}, "Troops")
local dummyFn = function(arg) end

local r1 = m:addCommand({"CTLD Commands","Troops"}, "Infantry", dummyFn, {size=6})
ok("T10: valid addCommand success",             r1.success == true)

local r2 = m:addCommand({"CTLD Commands","Troops"}, "BadArg", dummyFn, "not_a_table")
ok("T11: non-table anyArgument returns failure", r2.success == false)

local r3 = m:addCommand({"CTLD Commands","Troops"}, "NoFn", nil, {})
ok("T12: nil function returns failure",         r3.success == false)

local r4 = m:addCommand({"CTLD Commands","Troops","Infantry"}, "Sub", dummyFn, {})
ok("T13: addCommand under command node fails",  r4.success == false)

local result = string.format("U-47: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-47] " .. result)
