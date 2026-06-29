-- diag_cleanup_countryside_farp.lua
-- Destroys all objects spawned by previous Countryside FARP diag scenes.
-- Prefixes: CS_FARP, CS_FARP_Flag_, Fuel_Truck_Grp, repare_Truck_Grp,
--           FARP_Tent, ammo_box_cargo, CS_FARP_Guard_Grp, LightOn, Windsock, carrier_shooter

return (function()
    local prefixes = {
        "CS_FARP",
        "Fuel_Truck_Grp", "Fuel_Truck_Unit",
        "repare_Truck_Grp", "repare_Truck_Unit",
        "FARP_Tent",
        "ammo_box_cargo",
        "CS_FARP_Guard_Grp", "CS_Guard_Infantry", "CS_Guard_Manpad",
        "LightOn",
        "Windsock",
        "carrier_shooter",
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

    -- Destroy ground groups (trucks and guards are GROUND type)
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
