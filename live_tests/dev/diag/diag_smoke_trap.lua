---@diagnostic disable
-- diag_smoke_trap.lua
-- Monkey-patches trigger.action.smoke to log every call.
-- Install BEFORE reproducing the smoke bug, then read CTLD.log or screen for details.
-- Uninstall with: trigger.action.smoke = _orig_smoke (run diag_smoke_untrap.lua)

local _orig_smoke = trigger.action.smoke

_G._orig_smoke = _orig_smoke  -- save globally so untrap can restore it

trigger.action.smoke = function(pos, color)
    local info = string.format("[SMOKE TRAP] color=%s pos=(%s,%s,%s)",
        tostring(color),
        tostring(pos and pos.x), tostring(pos and pos.y), tostring(pos and pos.z))
    -- Print to screen (visible in DCS)
    trigger.action.outText(info, 20)
    -- Also log (if CTLD debug enabled)
    if ctld and ctld.utils and ctld.utils.log then
        ctld.utils.log("WARN", info)
    end
    -- Call original
    _orig_smoke(pos, color)
end

trigger.action.outText("[SMOKE TRAP] installed — trigger.action.smoke is now logged", 10)
return "smoke trap installed"
