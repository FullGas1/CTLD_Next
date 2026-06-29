-- diag_patch_getTask.lua — patch spawnJTAC to guard getTask (old build)
local _orig = CTLDJTACManager.spawnJTAC
CTLDJTACManager.spawnJTAC = function(self, groupName, cfg, spawner)
    -- Temporarily make getController return a safe proxy if getTask doesn't exist
    local dcsGroup = Group.getByName(groupName)
    if dcsGroup then
        local ctrl = dcsGroup:getController()
        if ctrl and not ctrl.getTask then
            ctrl.getTask = function() return nil end
        end
    end
    return _orig(self, groupName, cfg, spawner)
end
env.info("[PATCH] spawnJTAC getTask guarded")
return "patched"
