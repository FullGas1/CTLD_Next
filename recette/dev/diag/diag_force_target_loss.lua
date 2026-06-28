-- diag_force_target_loss.lua
-- Force target loss on flying JTAC to test route restoration without destroying the target.
-- Stops autoLase then clears currentTarget so _updateOrbit branch 3 fires on next tick.
local mgr = CTLDJTACManager.get()
local gname, jtac
for k, j in pairs(mgr.jtacs) do
    if j.isFlying then gname, jtac = k, j; break end
end
if not jtac then return "NO_FLYING_JTAC" end

-- Stop the autoLase search cycle so it cannot re-acquire a target
mgr:stopAutoLase(gname)

-- Clear currentTarget — branch 3 of _updateOrbit will fire on next tick (~3s)
jtac.currentTarget = nil
jtac.onTargetOrbit = true   -- keep true so branch 3 (not branch 4) handles it

trigger.action.outText(string.format(
    "[force_loss] %s | target cleared | _orbitLoop will restore route in ~3s", gname), 15)
ctld.utils.log("INFO", "[force_loss] currentTarget cleared on %s", gname)
return "OK: target cleared on " .. gname
