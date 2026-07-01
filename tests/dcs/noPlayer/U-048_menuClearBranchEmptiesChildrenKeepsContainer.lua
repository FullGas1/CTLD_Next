---@diagnostic disable
-- U-48 : ctld.Menu:clearBranch — empties children, keeps container
trigger.action.outText("U-48: clearBranch — empties children, keeps container", 10)

local log = function(msg) env.info("[U-48] " .. msg) end
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

local m  = ctld.MenuManager:getInstance():createMenuForGroup(3)
local fn = function() end
m:addSubMenu({}, "CTLD Commands", { order=100 })
m:addSubMenu({"CTLD Commands"}, "Pack Vehicles", { order=30 })
m:addCommand({"CTLD Commands","Pack Vehicles"}, "M1 Abrams", fn, {})
m:addCommand({"CTLD Commands","Pack Vehicles"}, "HMMWV",     fn, {})

local packNode = m:_getNode({"CTLD Commands","Pack Vehicles"})
ok("T14: before clearBranch children=2",    #packNode.children == 2)

local rc = m:clearBranch({"CTLD Commands","Pack Vehicles"})
ok("T15: clearBranch success",              rc.success == true)
ok("T15b: children=0 after clearBranch",    #packNode.children == 0)

local ctldNode = m:_getNode({"CTLD Commands"})
local still = false
for _, c in ipairs(ctldNode.children) do
    if c.name == "Pack Vehicles" then still = true end
end
ok("T16: container node still in parent",   still == true)

local result = string.format("U-48: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-48] " .. result)
