---@diagnostic disable
local pm = CTLDPlayerManager.getInstance()
local SLOT = "auto"
for k in pairs(pm._players) do if k:find("CH%-47") then SLOT = k; break end end
local pObj = pm._players[SLOT]
local transport = Unit.getByName(SLOT)
local inAir = transport and ctld.utils.inAir(transport)

local cm = CTLDCrateManager.getInstance()
local msg = "[DIAG CRATES ONBOARD] slot=" .. SLOT .. " inAir=" .. tostring(inAir) .. "\n"
local ctldManaged, dcsNative, total = 0, 0, 0
for _, crate in pairs(cm.crates) do
    if crate:isLoaded() and crate.loadedBy == transport then
        total = total + 1
        local managed = crate:isLoadedByCTLD()
        if managed then ctldManaged = ctldManaged + 1 else dcsNative = dcsNative + 1 end
        local desc = crate.descriptor and crate.descriptor.desc or crate.crateName
        msg = msg .. string.format("  %s | dcsStatic=%s isLoadedByCTLD=%s\n",
            desc, tostring(crate.dcsStatic ~= nil), tostring(managed))
    end
end
msg = msg .. string.format("Total=%d ctldManaged=%d dcsNative=%d\n", total, ctldManaged, dcsNative)

-- Parachute Crates menu state
local mmgr = ctld.MenuManager:getInstance()
local menu = pObj and mmgr:getMenuByGroupId(pObj.groupId)
local function fn(parent, name)
    if not parent or not parent.children then return nil end
    for _, c in ipairs(parent.children) do if c.name == name then return c end end
end
local root = ctld.tr("CTLD")
local crSub = ctld.tr("Crate Commands")
local pn = menu and fn(fn(fn(menu, root), crSub), ctld.tr("Parachute Crates"))
msg = msg .. "Parachute Crates: " .. (pn and ("enabled=" .. tostring(pn.enabled)) or "nil") .. "\n"

trigger.action.outText(msg, 30)
return msg
