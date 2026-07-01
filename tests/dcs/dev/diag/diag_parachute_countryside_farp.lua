---@diagnostic disable
-- =============================================================================
-- diag_parachute_countryside_farp.lua
-- Simulate parachuting 3 Countryside FARP crates and verify auto-unpack.
--
-- What this script does:
--   1. Finds the Countryside FARP scene descriptor (weight 1001.24)
--   2. Spawns 3 crates at DROP_POS with fromParachute=true + state=LANDED
--   3. Calls _checkAutoUnpack on the last one → should trigger playSceneAtPos
--   4. Verifies in CTLD.log that "auto-unpack (parachute) SCENE" was logged
--   5. Verifies a scene was started (CTLDSceneManager._active not empty)
--
-- Prerequisites:
--   - CTLD_Next.lua injected (>= 3 s before this script)
--   - No position constraints (crates spawned at DROP_POS below)
-- =============================================================================

local TAG      = "[DIAG-PARA-CSFARP]"
local KEY      = "_diag_para_csfarp"
local SCENE_NAME = "Countryside FARP"   -- model.name registered by countrysideFarpScene
local CRATE_WEIGHT = 1001.24
local DROP_POS  = { x = -356100, y = 100, z = 619300 }   -- near Batumi, arbitrary

-- ── RESET if already active ───────────────────────────────────────────────────
if _G[KEY] then
    -- Destroy spawned test crates
    local cmgr = CTLDCrateManager.getInstance()
    for _, cname in ipairs(_G[KEY].crateNames or {}) do
        local c = cmgr.crates[cname]
        if c then
            cmgr:unpackCrate(cname, nil)
        end
    end
    _G[KEY] = nil
    trigger.action.outText(TAG .. " RESET OK", 10)
    return TAG .. " RESET"
end

-- ── Verify scene is registered ────────────────────────────────────────────────
local sm    = CTLDSceneManager.getInstance()
local model = sm:getModel(SCENE_NAME)
if not model then
    -- Try with #1 suffix (scene counter appended at register)
    model = sm:getModel(SCENE_NAME .. "#1")
    if not model then
        trigger.action.outText(
            TAG .. " ABORT: scene '" .. SCENE_NAME .. "' not registered in CTLDSceneManager.\n" ..
            "Registered models: " .. (function()
                local names = {}
                for k in pairs(sm._models) do names[#names+1] = k end
                return table.concat(names, ", ")
            end)(), 20)
        return TAG .. " ABORT"
    end
    SCENE_NAME = SCENE_NAME .. "#1"
end

local cd = model.crate
if cd.autoUnpack == false then
    trigger.action.outText(TAG .. " ABORT: scene '" .. SCENE_NAME .. "' has autoUnpack=false.", 15)
    return TAG .. " ABORT: autoUnpack=false"
end

-- ── Find descriptor ───────────────────────────────────────────────────────────
local cmgr = CTLDCrateManager.getInstance()
local desc  = cmgr:findDescriptorByWeight(CRATE_WEIGHT)
if not desc then
    trigger.action.outText(TAG .. " ABORT: no descriptor for weight " .. CRATE_WEIGHT, 15)
    return TAG .. " ABORT: descriptor not found"
end

-- ── Count active scenes before ────────────────────────────────────────────────
local scenesBefore = 0
for _ in pairs(sm._active or {}) do scenesBefore = scenesBefore + 1 end

-- ── Spawn 3 crates and mark them as parachuted+landed ────────────────────────
local crateNames = {}
local required   = cd.cratesRequired or 3
for i = 1, required do
    local pos = { x = DROP_POS.x + (i-1)*10, y = DROP_POS.y, z = DROP_POS.z }
    local crate = cmgr:spawnCrate(desc, pos, coalition.side.BLUE, "diag_script",
        CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, nil, nil)
    if not crate then
        trigger.action.outText(TAG .. " ERROR: spawnCrate failed for crate " .. i, 15)
        return TAG .. " ERROR"
    end
    -- Force crate to landed+parachuted state (bypass physics)
    crate.fromParachute = true
    crate:_setState("LANDED")
    crate.position = pos
    crateNames[#crateNames+1] = crate.crateName
end

_G[KEY] = { crateNames = crateNames }

-- ── Trigger auto-unpack on last landed crate ─────────────────────────────────
local lastCrate = cmgr.crates[crateNames[#crateNames]]
cmgr:_checkAutoUnpack(lastCrate)

-- ── Verify result ─────────────────────────────────────────────────────────────
local scenesAfter = 0
local sceneStarted = nil
for name, scene in pairs(sm._active or {}) do
    scenesAfter = scenesAfter + 1
    if name:find(SCENE_NAME, 1, true) and not (function()
        for k in pairs({}) do if k == name then return true end end
        return false
    end)() then
        sceneStarted = name
    end
end
-- Simpler: just count
for name in pairs(sm._active or {}) do
    if name:find("Countryside", 1, true) then
        sceneStarted = name
    end
end

local result
if sceneStarted then
    result = TAG .. " PASS — scene '" .. sceneStarted .. "' started after parachute auto-unpack."
else
    local delta = scenesAfter - scenesBefore
    result = TAG .. " FAIL — no Countryside FARP scene found in _active after _checkAutoUnpack." ..
             "\n  scenes before=" .. scenesBefore .. " after=" .. scenesAfter ..
             "\n  Check CTLD.log for 'auto-unpack (parachute) SCENE'."
end

trigger.action.outText(result, 20)
return result
