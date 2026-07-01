---@diagnostic disable
-- U-45 : ctld.MenuManager singleton + createMenuForGroup
-- Witchcraft recette — no DCS API required (mock embedded)
trigger.action.outText("U-45: MenuManager singleton + createMenuForGroup", 10)

local log = function(msg) env.info("[U-45] " .. msg) end
local pass, fail = 0, 0
local function ok(label, cond)
    if cond then pass = pass + 1; log("PASS " .. label)
    else fail = fail + 1; log("FAIL " .. label) end
end

-- Mocks
missionCommands = missionCommands or {
    addSubMenuForGroup  = function() end,
    addCommandForGroup  = function() end,
    removeItemForGroup  = function() end,
}
ctld = ctld or {}
ctld.tr         = ctld.tr         or function(k) return k end
ctld.logInfo    = ctld.logInfo    or function() end
ctld.logWarning = ctld.logWarning or function() end
ctld.logError   = ctld.logError   or function() end
Unit      = Unit      or { getByName = function() return nil end, getByID = function() return nil end }
coalition = coalition or { getGroups = function() return {} end }

-- Reset singleton
ctld.MenuManager._instance = nil

local mgr1 = ctld.MenuManager:getInstance()
local mgr2 = ctld.MenuManager:getInstance()
ok("T01: getInstance() same object",        mgr1 == mgr2)

local menu = mgr1:createMenuForGroup(100)
ok("T02: createMenuForGroup returns non-nil", menu ~= nil)
ok("T03: menu.groupId correct",             menu and menu.groupId == 100)

local menu2 = mgr1:createMenuForGroup(100)
ok("T04: idempotent — returns same menu",   menu == menu2)

local menuB = mgr1:createMenuForGroup(200)
ok("T05: different groupIds — independent menus", menu ~= menuB)

local result = string.format("U-45: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-45] " .. result)
