---@diagnostic disable
-- diag_pack_vehicle.lua — état détection véhicules packables

local SLOT = "auto"
local pm   = CTLDPlayerManager.getInstance()
for k in pairs(pm._players) do
    if k:find("CH%-47") then SLOT = k; break end
end

local pObj = pm._players[SLOT]
if not pObj then
    trigger.action.outText("[DIAG] slot introuvable", 10)
    return
end

local unit = Unit.getByName(SLOT)
local pt   = unit and unit:getPoint()

local msg = "[DIAG PACK VEHICLE]\nslot=" .. SLOT .. "\n"
msg = msg .. "unit pos: x=" .. (pt and math.floor(pt.x) or "?") .. " z=" .. (pt and math.floor(pt.z) or "?") .. "\n"

-- Check CTLDCrateManager for deployed vehicles
local cm = CTLDCrateManager.getInstance()
msg = msg .. "\n[Deployed vehicles in registry]:\n"
local count = 0
for name, crate in pairs(cm._crates or {}) do
    if crate.state == "deployed" and crate.descriptor and crate.descriptor.unit then
        count = count + 1
        local cp = crate.pos or {}
        msg = msg .. string.format("  %s | unit=%s state=%s x=%.0f z=%.0f\n",
            tostring(name), tostring(crate.descriptor.unit),
            tostring(crate.state),
            cp.x or 0, cp.z or 0)
        if pt then
            local dx = (cp.x or 0) - pt.x
            local dz = (cp.z or 0) - pt.z
            msg = msg .. string.format("    dist=%.0fm\n", math.sqrt(dx*dx+dz*dz))
        end
    end
end
if count == 0 then msg = msg .. "  (aucun)\n" end

-- Search radius
local radius = ctld.gs("vehicleSearchDistance") or ctld.gs("vehicleSearchRadius") or 200
msg = msg .. "\nvehicleSearchDistance=" .. tostring(radius) .. "\n"

trigger.action.outText(msg, 40)
return msg
