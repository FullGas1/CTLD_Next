---@diagnostic disable
-- diag_crates_inflight.lua — état caisses CTLD en transit + état vol

local pm = CTLDPlayerManager.getInstance()
local SLOT = "auto"
for k in pairs(pm._players) do
    if k:find("CH%-47") then SLOT = k; break end
end
local pObj = pm._players[SLOT]
local transport = Unit.getByName(SLOT)

local inAir = transport and ctld.utils.inAir(transport)
local caps  = (ctld.gs("capabilitiesByType") or {})[pObj and pObj.typeName or ""]

local msg = "[DIAG CRATES INFLIGHT]\nslot=" .. SLOT .. "\n"
msg = msg .. "inAir=" .. tostring(inAir) .. "\n"
msg = msg .. "canParachuteDrop=" .. tostring(caps and caps.canParachuteDrop) .. "\n\n"

-- CTLD crates in transit
local cm = CTLDCrateManager.getInstance()
local inTransit = cm._inTransitCrates and cm._inTransitCrates[SLOT]
msg = msg .. "CTLD _inTransitCrates: "
if inTransit and #inTransit > 0 then
    msg = msg .. #inTransit .. " caisse(s)\n"
    for i, c in ipairs(inTransit) do
        msg = msg .. string.format("  [%d] %s\n", i, tostring(c.crateName or c.desc or "?"))
    end
else
    msg = msg .. "nil/vide\n"
end

-- DCS internal cargo weight
local internalWeight = 0
if transport and transport.getInternalCargo then internalWeight = transport:getInternalCargo() or 0 end
msg = msg .. "DCS internalCargo=" .. tostring(internalWeight) .. " kg\n"

-- Menu state for Parachute Crates
local mmgr = ctld.MenuManager:getInstance()
local menu = pObj and mmgr:getMenuByGroupId(pObj.groupId)
local function findNode(parent, name)
    if not parent or not parent.children then return nil end
    for _, c in ipairs(parent.children) do if c.name == name then return c end end
    return nil
end
local root = ctld.tr("CTLD")
local crSub = ctld.tr("Crate Commands")
local paraCrates = ctld.tr("Parachute Crates")
local rn = menu and findNode(menu, root)
local cn = rn and findNode(rn, crSub)
local pn = cn and findNode(cn, paraCrates)
msg = msg .. "Menu 'Parachute Crates': " .. (pn and ("enabled=" .. tostring(pn.enabled)) or "nil") .. "\n"

trigger.action.outText(msg, 30)
return msg
