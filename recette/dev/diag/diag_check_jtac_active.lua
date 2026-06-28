-- diag_check_jtac_active.lua — check active JTACs in CTLDJTACManager
local mgr   = CTLDJTACManager.get()
local count = 0
local lines = {}
for gname, jtac in pairs(mgr.jtacs) do
    count = count + 1
    table.insert(lines, string.format("%s state=%s laser=%s",
        gname,
        tostring(jtac.state),
        tostring(jtac.laserCode)))
end
if count == 0 then return "NO_ACTIVE_JTACS" end
return table.concat(lines, " | ")
