trigger.action.setUserFlag("MISSION_RESTART", 1)
local val = trigger.misc.getUserFlag("MISSION_RESTART")
return "MISSION_RESTART = " .. tostring(val)
