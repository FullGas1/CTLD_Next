---@diagnostic disable
-- live_tests/scenarios/interactive/spawn_metal_farp_at_coord.lua
-- Injectable (Witchcraft): executes the "Metal FARP" scene at the position
-- of the static object named "coord_farp-1".
-- The helipad spawns 58 m north of the anchor by scene design (step 1 polar offset).
-- ============================================================

-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SPAWN-METAL-FARP] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local TAG   = "[METAL-FARP-SPAWN]"
local START = os.date("%Y-%m-%d %H:%M:%S")
trigger.action.outText(TAG .. " START " .. START, 10)

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local ok, err = pcall(function()

    local anchor = StaticObject.getByName("coord_farp-1")
    if not anchor or not anchor:isExist() then
        trigger.action.outText(TAG .. " [FAIL] static 'coord_farp-1' not found", 15)
        return
    end

    local pos         = anchor:getPoint()
    local coalitionId = anchor:getCoalition()
    local countryId   = anchor:getCountry()

    ctld.utils.log("info", TAG .. string.format(
        " anchor pos=(%.1f, %.1f, %.1f) coa=%d cty=%d",
        pos.x, pos.y, pos.z, coalitionId, countryId))

    local scene = CTLDSceneManager.getInstance():playSceneAtPos(
        "Metal FARP", pos, coalitionId, countryId)

    if scene then
        trigger.action.outText(TAG .. string.format(
            " [OK] Metal FARP scene started at (%.0f, %.0f)", pos.x, pos.z), 15)
    else
        trigger.action.outText(TAG .. " [FAIL] playSceneAtPos returned nil", 15)
    end

end)

if not ok then
    trigger.action.outText(TAG .. " [ERROR] " .. tostring(err), 15)
    ctld.utils.log("error", TAG .. " [ERROR] " .. tostring(err))
end

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
trigger.action.outText(TAG .. " ✅ DONE", 20, true)
return "done"
