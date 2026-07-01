---@diagnostic disable
-- diag_para_realtime.lua
-- Snapshot _inTransit + menu memory + inAir state for CH-47

local SLOT = "Batumi_CH-47F_653-1"
local pm   = CTLDPlayerManager.getInstance()
local pObj = pm._players[SLOT]
if not pObj then
    trigger.action.outText("[DIAG] slot introuvable", 10)
    return "[DIAG] ABORT"
end

local tm   = CTLDTroopManager.getInstance()
local list = tm._inTransit[SLOT]

local unit  = Unit.getByName(SLOT)
local inAir = unit and ctld.utils.inAir(unit)
local hasTroops = tm:hasTroops(SLOT)

local caps  = (ctld.gs("capabilitiesByType") or {})[pObj.typeName]
local canPara = caps and caps.canParachuteDrop

local msg = "[DIAG PARA REALTIME]\n"
msg = msg .. "slot: " .. SLOT .. "\n"
msg = msg .. "inAir: " .. tostring(inAir) .. "\n"
msg = msg .. "hasTroops: " .. tostring(hasTroops) .. "\n"
msg = msg .. "canParachuteDrop: " .. tostring(canPara) .. "\n"

if list then
    msg = msg .. "_inTransit: " .. #list .. " group(s)\n"
    for i, g in ipairs(list) do
        msg = msg .. "  [" .. i .. "] " .. tostring(g.templateName) .. "\n"
    end
else
    msg = msg .. "_inTransit: nil\n"
end

-- Menu memory snapshot
local mmgr     = ctld.MenuManager:getInstance()
local menu     = mmgr:getMenuByGroupId(pObj.groupId)
local root     = ctld.tr("CTLD")
local troopSub = ctld.tr("Troop Commands")
local paraLabel= ctld.tr("Parachute Troops")

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

msg = msg .. "\nMenu memory (Troop children=" .. tostring(troopNode and #(troopNode.children or {}) or "n/a") .. "):\n"
if troopNode then
    for _, c in ipairs(troopNode.children or {}) do
        msg = msg .. "  [" .. tostring(c.type) .. "] " .. tostring(c.name) .. "\n"
        if c.children then
            for _, cc in ipairs(c.children) do
                msg = msg .. "    [" .. tostring(cc.type) .. "] " .. tostring(cc.name) .. "\n"
            end
        end
    end
end
msg = msg .. "  Parachute node: " .. (paraNode and ("type=" .. tostring(paraNode.type)) or "nil") .. "\n"

trigger.action.outText(msg, 40)
return msg
