---@diagnostic disable
-- =============================================================================
-- ctld_test.lua — CTLD test helper module
--
-- Inject once before any scenario that uses ctld_test.cleanup() / ctld_test.getTransport().
-- Usage:  node bridge.js ctld_test.lua    (then inject the scenario)
-- =============================================================================

if not ctld or not ctld.utils then
    trigger.action.outText("[ctld_test] ABORT: CTLD not initialized.", 10)
    return Witchcraft
end

ctld_test = ctld_test or {}

--- Remove all CTLD crates from the game world and reset manager state.
-- Also resets CTLDFOBManager and CTLDVehicleSpawner loaded-vehicle tables.
function ctld_test.cleanup()
    -- 1. Remove all crates (static objects) managed by CTLDCrateManager
    local ok_cm, cm = pcall(CTLDCrateManager.getInstance)
    if ok_cm and cm and cm.crates then
        for _, crate in pairs(cm.crates) do
            pcall(function()
                if crate.staticName then
                    local so = StaticObject.getByName(crate.staticName)
                    if so and so:isExist() then so:destroy() end
                end
            end)
        end
        cm.crates = {}
    end

    -- 2. Wipe FOB manager state
    local ok_fm, fm = pcall(CTLDFOBManager.getInstance)
    if ok_fm and fm then
        if fm._fobs    then fm._fobs    = {} end
        if fm._scenes  then fm._scenes  = {} end
    end

    -- 3. Clear vehicle spawner loaded-vehicle tables
    local ok_vs, vs = pcall(CTLDVehicleSpawner.getInstance)
    if ok_vs and vs then
        if vs._loadedVehicles then vs._loadedVehicles = {} end
    end

    -- 4. Reset internal cargo weight for transport unit (if transport known)
    local u = ctld_test.getTransport()
    if u then
        pcall(trigger.action.setUnitInternalCargo, u:getName(), 0)
    end

    ctld.utils.log("INFO", "[ctld_test] cleanup done")
end

--- Return the BLUE player transport unit, or nil.
function ctld_test.getTransport()
    -- Prefer CTLD-registered player
    local ok_pm, pm = pcall(CTLDPlayerManager.getInstance)
    if ok_pm and pm and pm._players then
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() then return u end
        end
    end
    -- Fallback: any human-piloted BLUE unit
    for _, grp in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        for _, unit in ipairs(grp:getUnits() or {}) do
            if unit and unit:isExist() and unit:getPlayerName() then return unit end
        end
    end
    return nil
end

trigger.action.outText("[ctld_test] helper loaded", 5)
ctld.utils.log("INFO", "[ctld_test] helper loaded")
return Witchcraft
