-- diag_crate_cargo_flag.lua
-- After CTLD load + CTLD unload, check actual DCS static properties.
-- Verifies modelKey stored on CTLDCrate and canCargo on the live DCS static.
local mgr   = CTLDCrateManager.getInstance()
local lines = { "[CARGO_FLAG] crate audit:" }
for name, c in pairs(mgr.crates) do
    local pos = c.position
    local staticExists = c.dcsStatic ~= nil and c.dcsStatic:isExist()
    local desc = nil
    if staticExists then
        pos = c.dcsStatic:getPoint()
        local ok, d = pcall(function() return c.dcsStatic:getDesc() end)
        if ok then desc = d end
    end
    local canCargoVal = desc and desc.canCargo
    local massVal     = desc and desc.mass
    lines[#lines+1] = string.format(
        "  [%s] state=%-8s modelKey=%-8s dcsStatic=%-5s canCargo=%-5s mass=%s pos=(%.0f,%.1f,%.0f)",
        name, c.state,
        tostring(c.modelKey),
        tostring(staticExists),
        tostring(canCargoVal),
        tostring(massVal),
        pos.x, pos.y, pos.z)
end
env.info(table.concat(lines, "\n"))
