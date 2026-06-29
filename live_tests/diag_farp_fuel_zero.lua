-- diag_farp_fuel_zero.lua
-- Finds the Countryside FARP airbase (namePrefix CS_FARP), reads fuel levels,
-- zeroes them via setLiquidAmount, then reads again to confirm.

return (function()
    -- Find the CS_FARP airbase via world.getAirbases()
    -- coalition.getAirbases() does NOT return dynamically spawned FARP airbases.
    local farp = nil
    local farpName = nil
    for _, ab in ipairs(world.getAirbases() or {}) do
        local ok, name = pcall(function() return ab:getName() end)
        if ok and name and name:sub(1, 7) == "CS_FARP" then
            -- verify warehouse is accessible (ghost entries have getWarehouse ok=false)
            local okW, w = pcall(function() return ab:getWarehouse() end)
            if okW and w then
                farp = ab
                farpName = name
                break
            end
        end
    end

    if not farp then
        return "ERR: no CS_FARP airbase found — deploy Countryside FARP first"
    end

    local w = farp:getWarehouse()
    if not w then
        return "ERR: getWarehouse() returned nil for " .. farpName
    end

    local liquidNames = { [0]="JetFuel", [1]="AvGas", [2]="MW50", [3]="Diesel" }

    -- Read before
    local before = {}
    for i = 0, 3 do
        local ok, amt = pcall(function() return w:getLiquidAmount(i) end)
        before[i] = ok and amt or "ERR"
    end

    -- Zero out
    local zeroOk = true
    for i = 0, 3 do
        local ok, err = pcall(function() w:setLiquidAmount(i, 0) end)
        if not ok then
            zeroOk = false
        end
    end

    -- Read after
    local after = {}
    for i = 0, 3 do
        local ok, amt = pcall(function() return w:getLiquidAmount(i) end)
        after[i] = ok and amt or "ERR"
    end

    local lines = { "FARP: " .. farpName, "setLiquidAmount ok: " .. tostring(zeroOk) }
    for i = 0, 3 do
        lines[#lines+1] = string.format("  %s: %s -> %s",
            liquidNames[i], tostring(before[i]), tostring(after[i]))
    end
    return table.concat(lines, "\n")
end)()
