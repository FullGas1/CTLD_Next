---@diagnostic disable
-- diag_parachute_menu_state.lua
-- Dump _inTransit + menu memory state for parachute section

local SLOT = "Batumi_CH-47F_325-1"
local pm   = CTLDPlayerManager.getInstance()
local pObj = pm._players[SLOT]
if not pObj then
    trigger.action.outText("[DIAG] slot introuvable", 10)
    return "[DIAG] ABORT"
end

local tm   = CTLDTroopManager.getInstance()
local list = tm._inTransit[SLOT]

local msg = "[DIAG PARA MENU]\n"
msg = msg .. "unitName: " .. SLOT .. "\n"

if list then
    msg = msg .. "_inTransit: " .. #list .. " group(s)\n"
    for i, g in ipairs(list) do
        msg = msg .. "  [" .. i .. "] " .. tostring(g.templateName) .. "\n"
    end
else
    msg = msg .. "_inTransit: nil (vide)\n"
end

-- Check menu memory node for Parachute Troops
local mmgr = ctld.MenuManager:getInstance()
local menu = mmgr:getMenuByGroupId(pObj.groupId)
local root      = ctld.tr("CTLD")
local troopSub  = ctld.tr("Troop Commands")
local paraLabel = ctld.tr("Parachute Troops")

local function findNode(parent, name)
    if not parent or not parent.children then return nil end
    for _, c in ipairs(parent.children) do
        if c.name == name then return c end
    end
    return nil
end

local rootNode  = menu and findNode(menu, root)
local troopNode = rootNode and findNode(rootNode, troopSub)
local paraNode  = troopNode and findNode(troopNode, paraLabel)

msg = msg .. "\nMenu memory:\n"
msg = msg .. "  CTLD node: " .. (rootNode and "found" or "nil") .. "\n"
msg = msg .. "  Troop Commands: " .. (troopNode and "found" or "nil") .. "\n"
if troopNode then
    msg = msg .. "  Troop children (" .. #(troopNode.children or {}) .. "):\n"
    for _, c in ipairs(troopNode.children or {}) do
        msg = msg .. "    [" .. tostring(c.type) .. "] " .. tostring(c.name) .. "\n"
    end
end
msg = msg .. "  Parachute node: " .. (paraNode and ("type=" .. tostring(paraNode.type)) or "nil") .. "\n"
if paraNode and paraNode.children then
    for _, c in ipairs(paraNode.children) do
        msg = msg .. "    para child: " .. tostring(c.name) .. "\n"
    end
end

trigger.action.outText(msg, 30)
return msg
