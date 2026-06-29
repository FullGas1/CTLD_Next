---@diagnostic disable
-- diag_crate_menu.lua — dump Crate Commands + vehicle submenus

local pm = CTLDPlayerManager.getInstance()
local SLOT = "auto"
for k in pairs(pm._players) do
    if k:find("CH%-47") then SLOT = k; break end
end
local pObj = pm._players[SLOT]
if not pObj then return "[DIAG] ABORT" end

local mmgr = ctld.MenuManager:getInstance()
local menu = mmgr:getMenuByGroupId(pObj.groupId)

local function findNode(parent, name)
    if not parent or not parent.children then return nil end
    for _, c in ipairs(parent.children) do
        if c.name == name then return c end
    end
    return nil
end

local function dumpNode(node, indent)
    local s = ""
    for _, c in ipairs(node.children or {}) do
        s = s .. indent .. "[" .. tostring(c.type) .. "] " .. tostring(c.name)
        if c.enabled == false then s = s .. " (DISABLED)" end
        s = s .. "\n"
        if c.children then s = s .. dumpNode(c, indent .. "  ") end
    end
    return s
end

local root      = ctld.tr("CTLD")
local cratesSub = ctld.tr("Crate Commands")
local rootNode  = menu and findNode(menu, root)
local crateNode = rootNode and findNode(rootNode, cratesSub)

local msg = "[DIAG CRATE MENU]\n"
if crateNode then
    msg = msg .. dumpNode(crateNode, "  ")
else
    msg = msg .. "Crate Commands node: nil\n"
end

trigger.action.outText(msg, 40)
return msg
