---@diagnostic disable
-- U-51 : ORDER sorting — DCS rebuild follows order field, not insertion order
trigger.action.outText("U-51: ORDER sorting in rebuild", 10)

local log = function(msg) env.info("[U-51] " .. msg) end
local pass, fail = 0, 0
local function ok(label, cond)
    if cond then pass = pass + 1; log("PASS " .. label)
    else fail = fail + 1; log("FAIL " .. label) end
end

local _dcs_calls = {}
missionCommands = {
    addSubMenuForGroup  = function(gId, name, path) table.insert(_dcs_calls, {fn="addSubMenu", name=name, path=path}) end,
    addCommandForGroup  = function(gId, name, path) table.insert(_dcs_calls, {fn="addCommand", name=name, path=path}) end,
    removeItemForGroup  = function() end,
}
ctld = ctld or {}; ctld.tr=ctld.tr or function(k)return k end
ctld.logInfo=ctld.logInfo or function()end; ctld.logWarning=ctld.logWarning or function()end; ctld.logError=ctld.logError or function()end
Unit=Unit or {getByName=function()return nil end,getByID=function()return nil end}
coalition=coalition or {getGroups=function()return{}end}
ctld.MenuManager._instance = nil

local m = ctld.MenuManager:getInstance():createMenuForGroup(6)
-- Inserted in reverse order; expect DCS to receive: Troops(10), Crates(20), FOB(30)
m:addSubMenu({}, "CTLD Commands")
m:addSubMenu({"CTLD Commands"}, "FOB",    {order=30})
m:addSubMenu({"CTLD Commands"}, "Troops", {order=10})
m:addSubMenu({"CTLD Commands"}, "Crates", {order=20})
m:refresh()

local childCalls = {}
for _, c in ipairs(_dcs_calls) do
    if c.fn == "addSubMenu" and c.path and c.path[1] == "CTLD Commands" then
        table.insert(childCalls, c.name)
    end
end
ok("T21a: first = Troops (order=10)",   childCalls[1] == "Troops")
ok("T21b: second = Crates (order=20)",  childCalls[2] == "Crates")
ok("T21c: third = FOB (order=30)",      childCalls[3] == "FOB")

local result = string.format("U-51: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-51] " .. result)
