-- diag_force_orbit_reset.lua
-- Force reset orbit state → IDLE so _updateOrbit re-applies the route
-- and logs it to CTLD.log (debug must be true first)
local mgr = CTLDJTACManager.get()
local count = 0
for k, j in pairs(mgr.jtacs) do
    if j.isFlying then
        j:stopOrbit()           -- state → IDLE
        j.onTargetOrbit = false
        count = count + 1
        ctld.utils.log("INFO", "[force_orbit_reset] reset %s → IDLE (initPos=%s)",
            k, j.initialPosition and string.format("x=%.0f z=%.0f", j.initialPosition.x, j.initialPosition.z) or "nil")
    end
end
trigger.action.outText(string.format("[debug] %d drone(s) reset → IDLE, orbit route sera réappliqué dans ~3s", count), 10)
return string.format("reset %d drone(s)", count)
