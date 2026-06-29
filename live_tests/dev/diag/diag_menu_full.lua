---@diagnostic disable
-- diag_menu_full.lua — dump complet du menu memory pour le CH-47

local SLOT = "Batumi_CH-47F_678-1"
local pm   = CTLDPlayerManager.getInstance()
local pObj = pm._players[SLOT]
if not pObj then
    trigger.action.outText("[DIAG] slot introuvable: " .. SLOT, 10)
    return "[DIAG] ABORT"
end

local mmgr = ctld.MenuManager:getInstance()
local menu = mmgr:getMenuByGroupId(pObj.groupId)

local function dumpNode(node, indent)
    if not node then return "" end
    local s = ""
    local children = node.children or {}
    for _, c in ipairs(children) do
        s = s .. indent .. "[" .. tostring(c.type) .. "] " .. tostring(c.name)
        if c.enabled == false then s = s .. " (DISABLED)" end
        s = s .. "\n"
        if c.children then
            s = s .. dumpNode(c, indent .. "  ")
        end
    end
    return s
end

local msg = "[DIAG MENU FULL] slot=" .. SLOT .. " groupId=" .. tostring(pObj.groupId) .. "\n"
msg = msg .. "isTransport=" .. tostring(pObj.isTransport) .. " typeName=" .. tostring(pObj.typeName) .. "\n"
msg = msg .. "menu=" .. (menu and "found" or "nil") .. "\n"
if menu then
    msg = msg .. "root children=" .. #(menu.children or {}) .. "\n"
    msg = msg .. dumpNode(menu, "  ")
end

trigger.action.outText(msg, 40)
return msg
