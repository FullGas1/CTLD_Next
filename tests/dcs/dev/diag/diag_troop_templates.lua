---@diagnostic disable
-- diag_troop_templates.lua — dump templates + filtre capacité CH-47

local SLOT = "Batumi_CH-47F_678-1"
local pm   = CTLDPlayerManager.getInstance()
-- auto-detect slot
for k in pairs(pm._players) do
    if k:find("CH%-47") then SLOT = k; break end
end

local pObj = pm._players[SLOT]
local tm   = CTLDTroopManager.getInstance()

local caps  = (ctld.gs("capabilitiesByType") or {})[pObj and pObj.typeName or "CH-47Fbl1"]
local limit = pObj and tm:_transportLimit(pObj.typeName) or 0

local msg = "[DIAG TEMPLATES] slot=" .. SLOT .. "\n"
msg = msg .. "typeName=" .. tostring(pObj and pObj.typeName) .. "\n"
msg = msg .. "transportLimit=" .. tostring(limit) .. "\n\n"
msg = msg .. "All templates:\n"

for _, tmpl in ipairs(tm._templates or {}) do
    local sideOk  = (tmpl.side == nil or tmpl.side == (pObj and pObj.coalition))
    local sizeOk  = (tmpl.total <= limit)
    local status  = ""
    if not sideOk then status = status .. " FILTERED:side" end
    if not sizeOk then status = status .. " FILTERED:size(total=" .. tostring(tmpl.total) .. ">limit=" .. tostring(limit) .. ")" end
    if tmpl.disabled then status = status .. " DISABLED" end
    msg = msg .. string.format("  [%s] total=%s%s\n", tostring(tmpl.name), tostring(tmpl.total), status)
end

trigger.action.outText(msg, 40)
return msg
