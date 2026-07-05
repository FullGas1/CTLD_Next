---@diagnostic disable
-- cleanup_ctld_menus.lua
-- Wipe all CTLD F10 menus for all live player groups before a CTLD reinject.
-- Iterates all coalitions, finds groups with a live player, removes their CTLD menu handle.

local removed = 0

-- Try to remove via CTLDMenuManager if the old instance is alive.
if ctld and ctld.MenuManager then
    local mm = ctld.MenuManager:getInstance()
    if mm and mm.menus then
        for groupId, menu in pairs(mm.menus) do
            for _, item in ipairs(menu.children or {}) do
                if item._dcsHandle ~= nil then
                    pcall(missionCommands.removeItemForGroup, groupId, item._dcsHandle)
                    item._dcsHandle = nil
                    removed = removed + 1
                end
            end
        end
        mm.menus = {}
    end
end

-- Also nuke CTLDPlayerManager players so the new instance starts fresh.
if CTLDPlayerManager and CTLDPlayerManager._instance then
    CTLDPlayerManager._instance._players = {}
end

-- Nuke all CTLD singletons so the next CTLD_Next.lua injection creates fresh instances.
if CTLDCoreManager    then CTLDCoreManager._instance    = nil end
if CTLDPlayerManager  then CTLDPlayerManager._instance  = nil end
if CTLDCrateManager   then CTLDCrateManager._instance   = nil end
if CTLDTroopManager   then CTLDTroopManager._instance   = nil end
if CTLDJTACManager    then CTLDJTACManager._instance    = nil end
if CTLDVehicleSpawner then CTLDVehicleSpawner._instance = nil end
if CTLDSceneManager   then CTLDSceneManager._instance   = nil end
if CTLDFOBManager     then CTLDFOBManager._instance     = nil end
if CTLDBeaconManager  then CTLDBeaconManager._instance  = nil end

trigger.action.outText("[CTLD-CLEAN] Menus wiped (" .. removed .. " handles removed). Inject CTLD_Next.lua now.", 8)
return Witchcraft
