-- diag_cleanup_metal_farp.lua
-- Destroys all objects spawned by previous Metal FARP diag scenes.
-- Prefixes: FARP_Helipad, Fuel_Truck_Grp, repare_Truck_Grp, FARP_Tent, ammo_box_cargo, LightOn, Windsock

return (function()
    local prefixes = {
        "FARP_Helipad", "Fuel_Truck_Grp", "Fuel_Truck_Unit",
        "repare_Truck_Grp", "repare_Truck_Unit",
        "FARP_Tent", "ammo_box_cargo", "LightOn", "Windsock",
    }

    local destroyed = 0

    -- Destroy statics
    for _, cat in ipairs({ coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }) do
        local statics = coalition.getStaticObjects(cat)
        if statics then
            for _, obj in ipairs(statics) do
                local ok, name = pcall(function() return obj:getName() end)
                if ok and name then
                    for _, prefix in ipairs(prefixes) do
                        if name:sub(1, #prefix) == prefix then
                            obj:destroy()
                            destroyed = destroyed + 1
                            break
                        end
                    end
                end
            end
        end
    end

    -- Destroy ground groups (fuel/repair trucks are GROUND type)
    for _, cat in ipairs({ coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }) do
        local groups = coalition.getGroups(cat, Group.Category.GROUND)
        if groups then
            for _, grp in ipairs(groups) do
                local ok, name = pcall(function() return grp:getName() end)
                if ok and name then
                    for _, prefix in ipairs(prefixes) do
                        if name:sub(1, #prefix) == prefix then
                            grp:destroy()
                            destroyed = destroyed + 1
                            break
                        end
                    end
                end
            end
        end
    end

    return string.format("Cleanup done: %d objects destroyed", destroyed)
end)()
