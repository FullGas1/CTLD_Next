-- diag_kill_drones.lua — destroy all flying JTAC drones
local mgr = CTLDJTACManager.get()
local killed = {}
for k, j in pairs(mgr.jtacs) do
    if j.isFlying then
        local g = Group.getByName(k)
        if g then g:destroy() end
        killed[#killed+1] = k
    end
end
if #killed == 0 then
    trigger.action.outText("[debug] no flying drones to kill", 8)
    return "none"
end
trigger.action.outText(string.format("[debug] killed: %s", table.concat(killed, ", ")), 8)
return "killed: " .. table.concat(killed, ", ")
