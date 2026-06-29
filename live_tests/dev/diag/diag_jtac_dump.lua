-- diag_jtac_dump.lua — dump all JTAC state + live drone positions
local mgr = CTLDJTACManager.get()
local lines = { "[jtac_dump] --- JTAC Manager State ---" }

for k, j in pairs(mgr.jtacs) do
    local line = string.format("  [%s] state=%s isFlying=%s target=%s onTargetOrbit=%s",
        tostring(k),
        tostring(j.state),
        tostring(j.isFlying),
        tostring(j.currentTarget),
        tostring(j.onTargetOrbit))
    lines[#lines+1] = line

    if j.initialPosition then
        local ip = j.initialPosition
        lines[#lines+1] = string.format("    initPos x=%.0f z=%.0f", ip.x, ip.z)
    else
        lines[#lines+1] = "    initPos = nil"
    end

    local g = Group.getByName(k)
    local u = g and g:getUnits()[1]
    if u and u:isExist() then
        local p = u:getPoint()
        lines[#lines+1] = string.format("    livePos x=%.0f y=%.0f z=%.0f", p.x, p.y, p.z)

        -- Draw live mark
        trigger.action.removeMark(9400)
        trigger.action.markToAll(9400, string.format("[%s] live", k), p, false, "")
    else
        lines[#lines+1] = "    livePos = UNIT DEAD/MISSING"
    end
end

local msg = table.concat(lines, "\n")
ctld.utils.log("INFO", msg)
trigger.action.outText(msg, 20)
return "dump done"
