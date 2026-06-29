-- diag_check_drone_groups.lua
-- Check if drone groups from diag_spawn_drone exist and are in the correct state.

local names = { "CTLD_MQ9_BLUE_TEST", "CTLD_RQ1A_RED_TEST" }
for _, gname in ipairs(names) do
    local g = Group.getByName(gname)
    if g then
        local cat = g:getCategory()
        local sz  = g:getSize()
        local u1  = g:getUnit(1)
        local pos = u1 and u1:getPoint() or {}
        env.info(string.format("[CHECK_DRONE] %s → category=%d  size=%d  alt=%.0f",
            gname, cat, sz, pos.y or -1))
        -- Group.Category.AIRPLANE = 0, GROUND = 2
    else
        env.info("[CHECK_DRONE] " .. gname .. " → NOT FOUND")
    end
end
