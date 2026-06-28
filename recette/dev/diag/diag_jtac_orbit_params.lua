-- diag_jtac_orbit_params.lua — dump orbit params and effective radius
local mgr = CTLDJTACManager.get()
local lines = { "[orbit_params] ---" }

lines[#lines+1] = string.format("  jtacDroneRadius  = %s", tostring(ctld.gs("jtacDroneRadius")))
lines[#lines+1] = string.format("  jtacDroneAltitude= %s", tostring(ctld.gs("jtacDroneAltitude")))
lines[#lines+1] = string.format("  jtacDroneSpeed   = %s", tostring(ctld.gs("jtacDroneSpeed")))
lines[#lines+1] = string.format("  enableAutoOrbit  = %s", tostring(ctld.gs("enableAutoOrbitingFlyingJtacOnTarget")))

for k, j in pairs(mgr.jtacs) do
    if j.isFlying then
        local opStr = ""
        if j.orbitParams then
            for pk, pv in pairs(j.orbitParams) do
                opStr = opStr .. string.format("%s=%s ", pk, tostring(pv))
            end
        else opStr = "nil" end
        lines[#lines+1] = string.format("  [%s] orbitParams={%s}", k, opStr)
        local rNoLase = j.orbitParams and j.orbitParams.orbitRadiusNoLase or ctld.gs("jtacDroneRadius") or 1000
        local rOnLase = j.orbitParams and j.orbitParams.orbitRadiusOnLase or ctld.gs("jtacDroneRadius") or 1000
        lines[#lines+1] = string.format("    effective rNoLase=%.0f  rOnLase=%.0f", rNoLase, rOnLase)
        if j.initialPosition then
            local ip = j.initialPosition
            lines[#lines+1] = string.format("    initPos x=%.0f z=%.0f", ip.x, ip.z)
            -- Draw orbit circle at expected radius
            trigger.action.removeMark(9500)
            trigger.action.circleToAll(-1, 9500, ip, rNoLase,
                {0.1, 0.8, 0.1, 1.0}, {0.0, 0.0, 0.0, 0.0}, 1, false,
                string.format("expected orbit r=%.0f", rNoLase))
        end
    end
end

local msg = table.concat(lines, "\n")
ctld.utils.log("INFO", msg)
trigger.action.outText(msg, 20)
return "params dumped"
