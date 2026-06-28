-- diag_list_crates.lua — list all CTLD-tracked crates with name, state, position.
local mgr   = CTLDCrateManager.getInstance()
local lines = { "[CTLD_LIST] crates tracked by CTLDCrateManager:" }
local count = 0
for name, c in pairs(mgr.crates) do
    count = count + 1
    local pos = c.position
    if c.dcsStatic and c.dcsStatic:isExist() then
        pos = c.dcsStatic:getPoint()
    end
    lines[#lines + 1] = string.format(
        "  [%s] state=%-8s desc=%-20s pos=(%.0f, %.1f, %.0f) dcsStatic=%s",
        name,
        c.state,
        c.descriptor and c.descriptor.desc or "?",
        pos.x, pos.y, pos.z,
        tostring(c.dcsStatic ~= nil and c.dcsStatic:isExist()))
end
lines[#lines + 1] = "  total: " .. count
env.info(table.concat(lines, "\n"))
