---@diagnostic disable
-- U-52 : Pagination — 13 items → 9 + "→ Next Page" at F10
trigger.action.outText("U-52: Pagination 13 items → 9 + Next Page", 10)

local log = function(msg) env.info("[U-52] " .. msg) end
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

local fn = function() end
local m = ctld.MenuManager:getInstance():createMenuForGroup(7)
m:addSubMenu({}, "CTLD Commands")
m:addSubMenu({"CTLD Commands"}, "Vehicles")
for i = 1, 13 do
    m:addCommand({"CTLD Commands","Vehicles"}, "Vehicle_"..i, fn, {})
end
m:refresh()

local vehiclePath = {"CTLD Commands","Vehicles"}
local directItems, hasNextPage = 0, false
for _, c in ipairs(_dcs_calls) do
    if c.path then
        local match = (#c.path == #vehiclePath)
        if match then
            for i, seg in ipairs(vehiclePath) do
                if c.path[i] ~= seg then match=false; break end
            end
        end
        if match then
            if c.name == ctld.tr("→ Next Page") then hasNextPage=true
            else directItems = directItems + 1 end
        end
    end
end
ok("T22a: 9 items on page 1",              directItems == 9)
ok("T22b: '→ Next Page' submenu at F10",   hasNextPage == true)

local result = string.format("U-52: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-52] " .. result)
