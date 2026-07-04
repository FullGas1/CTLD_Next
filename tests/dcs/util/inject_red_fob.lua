---@diagnostic disable
-- =============================================================================
-- tests/dcs/util/inject_red_fob.lua
-- Utility: inject a fake RED FOB into CTLDFOBManager._fobs
-- Required by scenario_feature_f_recon_farp steps F-155
--
-- Inject once before scenario_feature_f_recon_farp.lua
-- =============================================================================

if not ctld or not ctld.utils then
    trigger.action.outText("[inject_red_fob] ABORT: CTLD not initialized.", 10)
    return Witchcraft
end

local TAG = "[inject_red_fob]"
local function log(msg) ctld.utils.log("INFO", TAG .. " " .. msg) end

-- Inject a mock RED FOB near Anapa airbase coords (far from BLUE Batumi)
local RED_FOB_POS = { x = -194000, y = 90, z = 630000 }
local RED_FOB_ID  = "RED_FOB_test_F155"

local fobMgr = CTLDFOBManager.getInstance()

-- Remove if already exists
if fobMgr._fobs[RED_FOB_ID] then
    log("removing previous red FOB")
    fobMgr._fobs[RED_FOB_ID] = nil
end

-- Build minimal CTLDFOB-compatible object
local fob = {
    fobId       = RED_FOB_ID,
    name        = RED_FOB_ID,
    coalitionId = coalition.side.RED,
    position    = RED_FOB_POS,
    _objects    = { { name = "FAKE_RED_FOB_OBJ" } },
    isAlive     = function(self)
        return true
    end,
    getIntegrityPercent = function(self)
        return 1.0
    end,
}

fobMgr._fobs[RED_FOB_ID] = fob
log("RED FOB injected at (" .. RED_FOB_POS.x .. ", " .. RED_FOB_POS.z .. ")")
trigger.action.outText(TAG .. " RED FOB injected (F-155)", 5)
return Witchcraft
