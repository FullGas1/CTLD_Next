---@diagnostic disable
-- U-46 : ctld.Menu:addSubMenu — guards, idempotence, nesting
trigger.action.outText("U-46: addSubMenu guards + idempotence + nesting", 10)

local log = function(msg) env.info("[U-46] " .. msg) end
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

local m = ctld.MenuManager:getInstance():createMenuForGroup(1)

local r1 = m:addSubMenu({}, "CTLD Commands")
ok("T06: addSubMenu root success",              r1.success == true)

local r2 = m:addSubMenu({}, "CTLD Commands")
ok("T07: addSubMenu idempotent success",        r2.success == true)
ok("T07b: children count unchanged after dup",  #m.children == 1)

local r3 = m:addSubMenu({"CTLD Commands"}, "Troops")
ok("T08: addSubMenu nested success",            r3.success == true)

local r4 = m:addSubMenu({}, "Bad", nil)
ok("T09: nil opts accepted",                    r4.success == true)

local result = string.format("U-46: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-46] " .. result)
