---@diagnostic disable
-- U-50 : removeMenuBranch — count + absence from memory
trigger.action.outText("U-50: removeMenuBranch count + absence", 10)

local log = function(msg) env.info("[U-50] " .. msg) end
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

local fn = function() end
local m  = ctld.MenuManager:getInstance():createMenuForGroup(5)
m:addSubMenu({}, "CTLD Commands")
m:addSubMenu({"CTLD Commands"}, "Troops")
m:addCommand({"CTLD Commands","Troops"}, "Infantry", fn, {})
m:addCommand({"CTLD Commands","Troops"}, "AntiAir",  fn, {})

local rr = m:removeMenuBranch({"CTLD Commands","Troops"})
ok("T19: removeMenuBranch success",         rr.success == true)
ok("T19b: removedCount = 3",                rr.removedCount == 3)

local gone = m:_getNode({"CTLD Commands","Troops"})
ok("T20: node absent after remove",         gone == nil)

local result = string.format("U-50: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-50] " .. result)
