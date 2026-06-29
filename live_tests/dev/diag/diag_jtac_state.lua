-- diag_jtac_state.lua
-- Dump initialRoute and current state of all flying JTACs.

local mgr = CTLDJTACManager.get()
local lines = {}

for gname, jtac in pairs(mgr.jtacs) do
    if jtac.isFlying then
        local hasPos   = jtac.initialPosition ~= nil
        local op       = jtac.orbitParams
        local opStr    = op and string.format("spd=%d alti=%d rNoLase=%d rOnLase=%d",
            op.speed or 0, op.alti or 0, op.orbitRadiusNoLase or 0, op.orbitRadiusOnLase or 0) or "NIL(fallback config)"
        local target   = jtac.currentTarget and jtac.currentTarget.unitName or "none"
        lines[#lines+1] = string.format(
            "%s | state=%s | initPos=%s | orbitParams=%s | target=%s",
            gname, tostring(jtac.state), tostring(hasPos), opStr, target)

        -- Also dump the current DCS group controller task
        local g = Group.getByName(gname)
        if g then
            local ok, task = pcall(function() return g:getController():getTask() end)
            if ok and task then
                lines[#lines+1] = string.format("  currentTask.id=%s", tostring(task.id))
            else
                lines[#lines+1] = "  currentTask=ERROR or nil"
            end
        end
    end
end

if #lines == 0 then return "NO_FLYING_JTAC" end

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 30)
env.info("[diag_jtac_state] " .. msg)
return msg
