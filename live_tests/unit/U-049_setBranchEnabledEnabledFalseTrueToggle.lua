---@diagnostic disable
-- U-49 : setBranchEnabled — enabled false/true toggle
trigger.action.outText("U-49: setBranchEnabled false/true", 10)

local log = function(msg) env.info("[U-49] " .. msg) end
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

local m = ctld.MenuManager:getInstance():createMenuForGroup(4)
m:addSubMenu({}, "CTLD Commands", { order=100 })
m:addSubMenu({"CTLD Commands"}, "Troops",  { order=10 })
m:addSubMenu({"CTLD Commands"}, "FOB",     { order=40, enabled=false })

local fobNode = m:_getNode({"CTLD Commands","FOB"})
ok("T17: FOB initially disabled",           fobNode.enabled == false)

m:setBranchEnabled({"CTLD Commands","FOB"}, true)
ok("T18: setBranchEnabled(true) toggles",   fobNode.enabled == true)

local result = string.format("U-49: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-49] " .. result)
