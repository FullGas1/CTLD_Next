-- diag_dump_initial_route.lua — dump initialRoute waypoints to verify coordinates
if mIdx == nil then mIdx = 9500 end
local function gidx() mIdx = mIdx + 1; return mIdx end

local mgr = CTLDJTACManager.get()
local gname, jtac
for k, j in pairs(mgr.jtacs) do
    if j.isFlying then gname, jtac = k, j; break end
end
if not jtac then return "NO_FLYING_JTAC" end

if not jtac.initialRoute then return "initialRoute = nil" end

local ip   = jtac.initialPosition
local cx   = ip and ip.x or 0
local cz   = ip and (ip.z or ip.y) or 0

local lines = { string.format("[route] group=%s center(%.0f,%.0f) r≈?", gname, cx, cz) }
for i, wp in ipairs(jtac.initialRoute) do
    local dx = wp.x - cx
    local dz = wp.y - cz    -- wp.y = DCS z-axis in waypoint table
    local dist = math.sqrt(dx*dx + dz*dz)
    local hasSW = wp.task and wp.task.params and wp.task.params.tasks and wp.task.params.tasks[1] ~= nil
    lines[#lines+1] = string.format("  WP%d (%.0f,%.0f) dist=%.0fm %s",
        i, wp.x, wp.y, dist, hasSW and "← SwitchWaypoint" or "")
    -- Draw WP mark
    trigger.action.markToAll(gidx(), string.format("WP%d %s", i, hasSW and "SW" or ""),
        { x = wp.x, y = wp.alt or 3000, z = wp.y }, false, "")
end

local msg = table.concat(lines, "\n")
ctld.utils.log("INFO", msg)
trigger.action.outText(msg, 30)
return "route dumped — " .. #jtac.initialRoute .. " WPs"
