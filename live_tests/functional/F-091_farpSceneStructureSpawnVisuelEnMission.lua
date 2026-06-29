---@diagnostic disable
-- ============================================================
-- F-91 : farpScene — structure + spawn visuel en mission
-- Module  : R4 (src/scenes/CTLD_farpScene.lua)
-- REQUIRES: DCS mission running, BLUE player in slot
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

-- ----------------------------------------------------------------
-- Purge objects spawned by the previous scene test run
-- ----------------------------------------------------------------
local function purgeLastScene()
    _CTLD_SCENE_LAST_SPAWNED = _CTLD_SCENE_LAST_SPAWNED or {}
    local destroyed = 0
    for _, name in ipairs(_CTLD_SCENE_LAST_SPAWNED) do
        local obj = StaticObject.getByName(name)
        if obj and obj:isExist() then
            obj:destroy()
            destroyed = destroyed + 1
        else
            local grp = Group.getByName(name)
            if grp then grp:destroy(); destroyed = destroyed + 1 end
        end
    end
    _CTLD_SCENE_LAST_SPAWNED = {}
    if destroyed > 0 then
        env.info(string.format("[F-91] purge: destroyed %d object(s) from previous run", destroyed))
    end
end
purgeLastScene()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_farpScene.lua")

ctld_test.start("F-91", "farpScene — structure 6 steps + spawn visuel")

-- ----------------------------------------------------------------
-- Part 1: Structure tests (unit)
-- ----------------------------------------------------------------
local mgr  = CTLDSceneManager.getInstance()
local farp = mgr:getModel("farpScene")

ctld_test.assertNotNil(farp,                                           "farpScene enregistré après dofile")
ctld_test.assertEqual(#farp.steps, 6,                                  "6 steps (prescript + 5 objets)")

ctld_test.assertNil(farp.steps[1].registryKey,                         "step 1 : prescript — pas de registryKey")
ctld_test.assertNotNil(farp.steps[1].func,                             "step 1 : prescript — func présente")
ctld_test.assertEqual(farp.steps[1].delayAfterPreviousStep, 0,         "step 1 : delay = 0")

ctld_test.assertEqual(farp.steps[2].registryKey, "SINGLE_HELIPAD",    "step 2 : registryKey = SINGLE_HELIPAD")
ctld_test.assertEqual(farp.steps[2].polar.distance, 0,                 "step 2 : polar.distance = 0 (au point ref)")
ctld_test.assertEqual(farp.steps[2].polar.angle, 0,                    "step 2 : polar.angle = 0")
ctld_test.assertEqual(farp.steps[2].delayAfterPreviousStep, 0,         "step 2 : delay = 0")

ctld_test.assertEqual(farp.steps[3].registryKey, "FARP_Tent",          "step 3 : registryKey = FARP_Tent")
ctld_test.assertEqual(farp.steps[3].polar.distance, 30,                "step 3 : polar.distance = 30")
ctld_test.assertEqual(farp.steps[3].polar.angle, 90,                   "step 3 : polar.angle = 90°")
ctld_test.assertEqual(farp.steps[3].delayAfterPreviousStep, 1,         "step 3 : delay = 1 s")

ctld_test.assertEqual(farp.steps[4].registryKey, "FARP_Ammo_Storage",  "step 4 : registryKey = FARP_Ammo_Storage")
ctld_test.assertEqual(farp.steps[4].polar.distance, 30,                "step 4 : polar.distance = 30")
ctld_test.assertEqual(farp.steps[4].polar.angle, 135,                  "step 4 : polar.angle = 135°")

ctld_test.assertEqual(farp.steps[5].registryKey, "Windsock",           "step 5 : registryKey = Windsock")
ctld_test.assertEqual(farp.steps[5].polar.distance, 15,                "step 5 : polar.distance = 15")
ctld_test.assertEqual(farp.steps[5].polar.angle, 270,                  "step 5 : polar.angle = 270°")

ctld_test.assertEqual(farp.steps[6].registryKey, "Fuel_Truck",         "step 6 : registryKey = Fuel_Truck")
ctld_test.assertEqual(farp.steps[6].polar.distance, 35,                "step 6 : polar.distance = 35")
ctld_test.assertEqual(farp.steps[6].polar.angle, 225,                  "step 6 : polar.angle = 225°")
ctld_test.assertEqual(farp.steps[6].delayAfterPreviousStep, 1,         "step 6 : delay = 1 s")

local allHaveAlt = true
for i = 2, 6 do
    if farp.steps[i].relativeAltitudeInMeters == nil then allHaveAlt = false; break end
end
ctld_test.assert(allHaveAlt,                                            "steps 2-6 ont relativeAltitudeInMeters")

ctld_test.finish()

-- ----------------------------------------------------------------
-- Part 2: Visual spawn
-- ----------------------------------------------------------------
local unit = ctld_test.getTransport()
if not unit then return end

env.info("[F-91] Triggering farpScene for unit: " .. unit:getName())

mgr:playScene(unit, "farpScene", {}, function(scene)
    env.info("[F-91] farpScene onComplete. Spawned: " .. #scene._spawnedObjs)
    _CTLD_SCENE_LAST_SPAWNED = {}
    for _, obj in ipairs(scene._spawnedObjs) do
        if obj and obj.getName then
            _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = obj:getName()
        end
    end
end)

trigger.action.outText(
    "F-91 VISUAL CHECK (farpScene):\n" ..
    "  - Ref point 50 m devant l'hélico\n" ..
    "  - SINGLE_HELIPAD au point de référence\n" ..
    "  - FARP_Tent ~30 m à 90° du helipad\n" ..
    "  - FARP_Ammo_Storage ~30 m à 135°\n" ..
    "  - Windsock ~15 m à 270°\n" ..
    "  - Fuel_Truck ~35 m à 225°", 30)
