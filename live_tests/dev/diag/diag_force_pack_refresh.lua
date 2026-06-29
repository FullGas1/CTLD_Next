---@diagnostic disable
-- Force refreshPackSection + dump résultat

local pm = CTLDPlayerManager.getInstance()
local SLOT = "auto"
for k in pairs(pm._players) do
    if k:find("CH%-47") then SLOT = k; break end
end
local pObj = pm._players[SLOT]
if not pObj then return "[DIAG] ABORT" end

-- Force refresh
CTLDVehicleSpawner.getInstance():refreshPackSection(pObj)

-- Dump menu
local mmgr = ctld.MenuManager:getInstance()
local menu = mmgr:getMenuByGroupId(pObj.groupId)

local function findNode(parent, name)
    if not parent or not parent.children then return nil end
    for _, c in ipairs(parent.children) do
        if c.name == name then return c end
    end
    return nil
end

local root      = ctld.tr("CTLD")
local cratesSub = ctld.tr("Crate Commands")
local packSub   = ctld.tr("Pack Vehicle")

local rootNode  = menu and findNode(menu, root)
local crateNode = rootNode and findNode(rootNode, cratesSub)
local packNode  = crateNode and findNode(crateNode, packSub)

local msg = "[DIAG PACK REFRESH]\n"
msg = msg .. "packNode children=" .. (packNode and #(packNode.children or {}) or "nil") .. "\n"
if packNode then
    for i, c in ipairs(packNode.children or {}) do
        msg = msg .. string.format("  [%d] %s\n", i, tostring(c.name))
    end
end

trigger.action.outText(msg, 30)
return msg
