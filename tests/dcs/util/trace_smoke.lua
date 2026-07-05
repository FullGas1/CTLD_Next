---@diagnostic disable
-- trace_smoke.lua
-- Intercepts trigger.action.smoke to log every call with a stack trace.
-- Inject once; stays active until mission restart.

local _orig_smoke = trigger.action.smoke

trigger.action.smoke = function(pos, color)
    local stack = ""
    local level = 2
    while true do
        local info = debug.getinfo(level, "Sl")
        if not info then break end
        stack = stack .. "\n  [" .. level .. "] " .. tostring(info.short_src) .. ":" .. tostring(info.currentline)
        level = level + 1
        if level > 10 then break end
    end
    local msg = "[SMOKE-TRACE] color=" .. tostring(color) .. stack
    trigger.action.outText(msg, 20)
    if ctld and ctld.utils then
        ctld.utils.log("INFO", msg)
    end
    return _orig_smoke(pos, color)
end

trigger.action.outText("[SMOKE-TRACE] trigger.action.smoke intercepté — reproduis le bug maintenant.", 10)
return Witchcraft
