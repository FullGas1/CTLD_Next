-- diag_spawn_metal_farp.lua
-- Spawns the Metal FARP scene directly on unit "uh1-1" for visual positioning validation.
-- Does NOT require a crate — calls playScene directly.
-- Inject via Witchcraft after CTLD_Next.lua is loaded.

return (function()
    local unitName = "uh1-1"
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then
        return "ERR: unit '" .. unitName .. "' not found or dead"
    end

    local sm = CTLDSceneManager.getInstance()
    local model = sm:getModel("Metal FARP")
    if not model then
        return "ERR: scene model 'Metal FARP' not registered"
    end

    trigger.action.outText("[DIAG] Spawning Metal FARP on " .. unitName .. " ...", 10)

    local scene = sm:playScene(unit, "Metal FARP", {}, function(s)
        trigger.action.outText("[DIAG] Metal FARP scene complete (" .. s._name .. ")", 10)
    end)

    if scene then
        return "OK: scene '" .. scene._name .. "' started — validate object positions visually"
    else
        return "ERR: playScene returned nil"
    end
end)()
