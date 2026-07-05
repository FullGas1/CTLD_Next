---@diagnostic disable
-- CTLD_metalFarpScene.lua
-- Metal FARP deployment scene — compact forward arming/refueling point using the
-- Farp_FG_Petit_Helipad mod (visible metallic helipad platform).
--
-- Requires the Farp_FG_Petit_Helipad mod to be installed on all clients.
-- probeSkip=true is set on the registry entry — the mod cannot be validated at runtime
-- (DCS getDesc().life == 0 whether the mod is installed or not).
--
-- Layout (all offsets from trigger unit position):
--   Farp_FG_Petit_Helipad heliport — 58 m ahead of trigger unit
--   Fuel truck              — 35 m / 8°   heading 90° (t+5 s)
--   Repair truck            — 35 m / 11°  heading 90° (t+5 s)
--   Tent                    — 35 m / 10°  heading 90° (t+5.5 s)
--   Ammo cargo              — 75 m / 346°             (t+10 s)
--   M92 light panel         — 75 m / 355° alt+4 m    (t+15 s)
--   Windsock                — 73 m / 346°             (t+15 s)
--   Warehouse stocking      — 10 000 L × 4 fuel types (t+20 s)
--
-- Dependencies: CTLDObjectRegistry, CTLDSceneManager, CTLDUtils
-- ====================================================================================================

-- ====================================================================================================
-- BLOCK 1 : i18n -- 4 mandatory languages
-- ====================================================================================================

ctld.i18n["en"]["Metal FARP Crate"]                                        = "Metal FARP Crate"
ctld.i18n["fr"]["Metal FARP Crate"]                                        = "Caisse FARP Métal"
ctld.i18n["es"]["Metal FARP Crate"]                                        = "Caja FARP Metal"
ctld.i18n["ko"]["Metal FARP Crate"]                                        = "메탈 FARP 화물"

ctld.i18n["en"]["Deploy Metal FARP"]                                       = "Deploy Metal FARP"
ctld.i18n["fr"]["Deploy Metal FARP"]                                       = "Déployer FARP Métal"
ctld.i18n["es"]["Deploy Metal FARP"]                                       = "Desplegar FARP Metal"
ctld.i18n["ko"]["Deploy Metal FARP"]                                       = "메탈 FARP 배치"

ctld.i18n["en"]["--- Metal FARP Deployment by %1 : Complete! ---"]        = "--- Metal FARP Deployment by %1 : Complete! ---"
ctld.i18n["fr"]["--- Metal FARP Deployment by %1 : Complete! ---"]        = "--- Déploiement FARP Métal par %1 : Terminé ! ---"
ctld.i18n["es"]["--- Metal FARP Deployment by %1 : Complete! ---"]        = "--- Despliegue FARP Metal por %1 : ¡Completo! ---"
ctld.i18n["ko"]["--- Metal FARP Deployment by %1 : Complete! ---"]        = "--- %1에 의한 메탈 FARP 배치 완료! ---"

-- ====================================================================================================
-- BLOCK 2 : Registry entries required by this scene.
-- registerIfAbsent() is a no-op when the key already exists.
-- ====================================================================================================

CTLDObjectRegistry.registerIfAbsent("Farp_FG_Petit_Helipad", {
    groupType            = "STATIC",
    namePrefix           = "FARP_Helipad",
    type                 = "Farp_FG_Petit_Helipad",
    category             = "Heliports",
    shape_name           = "Farp_FG_Petit_Helipad.edm",
    heliport_frequency   = "127.5",
    heliport_callsign_id = 1,
    heliport_modulation  = 0,
    -- DCS scripting API limitation: getDesc().life == 0 whether the mod is installed or not.
    -- probeSkip suppresses the false NOT FOUND alarm from CTLDModValidator.
    probeSkip            = true,
})

CTLDObjectRegistry.registerIfAbsent("Fuel_Truck", {
    groupType  = "GROUND",
    namePrefix = "Fuel_Truck_Grp",
    task       = "Ground Nothing",
    category   = Unit.Category.GROUND_UNIT,
    units = {
        {
            namePrefix     = "Fuel_Truck_Unit",
            unitType       = function(cid)
                return cid == coalition.side.RED and "ATZ-10" or "M978 HEMTT Tanker"
            end,
            playerCanDrive = false,
            dx = 0, dz = 0, dh = 0,
        },
    },
})

CTLDObjectRegistry.registerIfAbsent("repare_Truck", {
    groupType  = "GROUND",
    namePrefix = "repare_Truck_Grp",
    task       = "Ground Nothing",
    category   = Unit.Category.GROUND_UNIT,
    units = {
        {
            namePrefix     = "repare_Truck_Unit",
            unitType       = function(cid)
                return cid == coalition.side.RED and "Ural-375" or "M 818"
            end,
            playerCanDrive = false,
            dx = 0, dz = 0, dh = 0,
        },
    },
})

CTLDObjectRegistry.registerIfAbsent("FARP_Tent", {
    groupType  = "STATIC",
    namePrefix = "FARP_Tent",
    type       = "FARP Tent",
    category   = "Fortifications",
})

CTLDObjectRegistry.registerIfAbsent("ammo_cargo", {
    groupType  = "STATIC",
    namePrefix = "ammo_box_cargo",
    type       = "ammo_cargo",
    category   = "Cargos",
    shape_name = "ammo_box_cargo",
    rate       = 1,
})

CTLDObjectRegistry.registerIfAbsent("NF-2_LightOn", {
    groupType  = "STATIC",
    namePrefix = "LightOn",
    type       = "NF-2_LightOn",
    category   = "Fortifications",
    shape_name = "M92_NF-2_LightOn",
    rate       = 100,
})

CTLDObjectRegistry.registerIfAbsent("Windsock", {
    groupType  = "STATIC",
    namePrefix = "Windsock",
    type       = "Windsock",
    category   = "Fortifications",
    shape_name = "H-Windsock_RW",
    rate       = 3,
})

-- "us carrier shooter" is already registered in the global CTLDObjectRegistry default entries.

-- ====================================================================================================
-- BLOCK 3 : scene model + crate descriptor
-- ====================================================================================================

local metalFarpScene = {}
metalFarpScene.name       = "Metal FARP"
metalFarpScene.requiresMod = "Farp_FG_Petit_Helipad"  -- cannot be auto-validated (probeSkip); WARN emitted at init

metalFarpScene.crate = {
    weight         = 1001.26,
    i18nKey        = "Metal FARP Crate",
    deployKey      = "Deploy Metal FARP",
    groundKey      = "You must be on the ground to deploy a FARP.",
    cratesRequired = 1,
    side           = nil,
    showSets       = false,
}

metalFarpScene.steps = {

    -- ----------------------------------------------------------------
    -- Step 1: Farp_FG_Petit_Helipad heliport (delay=0).
    -- Spawned 50 m ahead of the trigger unit to avoid overlapping it.
    -- Saves the spawned airbase name for the warehouse-stocking step.
    -- critical=true: if the mod is absent the helipad cannot spawn; abort the whole scene
    -- rather than deploying trucks and a tent with no landing pad.
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 58, angle = 0 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey = "Farp_FG_Petit_Helipad",
        critical    = true,
        func = function(ctx)
            if not ctx.spawnedObj then return false end
            ctx.scene._params.farpName = ctx.spawnedObj:getName()
            return true
        end,
    },

    -- ----------------------------------------------------------------
    -- Step 2: Fuel truck — right side under tent (t0 + 5 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 60, angle = 342.5 },
        delayAfterPreviousStep   = 5,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "Fuel_Truck",
    },

    -- ----------------------------------------------------------------
    -- Step 3: Repair truck — left side under tent (t0 + 5 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 61, angle = 340.5 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "repare_Truck",
    },

    -- ----------------------------------------------------------------
    -- Step 4: Tent — over both trucks (t0 + 5.5 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 61, angle = 341 },
        delayAfterPreviousStep   = 0.5,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "FARP_Tent",
    },

    -- ----------------------------------------------------------------
    -- Step 5: Ammo cargo (t0 + 10 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 75, angle = 346 },
        delayAfterPreviousStep   = 4.5,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey = "ammo_cargo",
    },

    -- ----------------------------------------------------------------
    -- Step 6: M92 light panel at tent height (t0 + 15 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 75, angle = 355 },
        delayAfterPreviousStep   = 5,
        relativeHeadingInDegrees = 310,
        relativeAltitudeInMeters = 4,
        registryKey = "NF-2_LightOn",
    },

    -- ----------------------------------------------------------------
    -- Step 7: Windsock near the light, same timing (t0 + 15 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 73, angle = 346 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 220,
        relativeAltitudeInMeters = 0,
        registryKey = "Windsock",
    },

    -- ----------------------------------------------------------------
    -- Step 8: Carrier Seaman on the helipad (t0 + 15 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 67, angle = 2 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "us carrier shooter",
    },

    -- ----------------------------------------------------------------
    -- Step 9: Stock warehouse + completion message (t0 + 20 s).
    -- Fills all fuel types so aircraft can refuel/rearm at this point.
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 5,
        func = function(ctx)
            local farpName = ctx.scene._params and ctx.scene._params.farpName
            if farpName then
                local ab = Airbase.getByName(farpName)
                if ab then
                    local w = ab:getWarehouse()
                    -- If this is a redeployed FARP, restore the snapshot; otherwise stock defaults.
                    local snap = ctx.scene._params.repackData
                              and ctx.scene._params.repackData.warehouseSnapshot
                    if snap and snap.liquid then
                        for fuelType = 0, 3 do
                            w:setLiquidAmount(fuelType, snap.liquid[fuelType] or 0)
                        end
                    else
                        w:addLiquid(0, 10000)   -- jet fuel
                        w:addLiquid(1, 10000)   -- aviation gasoline
                        w:addLiquid(2, 10000)   -- MW50
                        w:addLiquid(3, 10000)   -- diesel
                    end
                end
            end
            trigger.action.outText(
                ctld.tr("--- Metal FARP Deployment by %1 : Complete! ---", ctx.unit:getName()), 10)
            return true
        end,
    },
}

-- ====================================================================================================
-- BLOCK 4 : onRepack — called by CTLDSceneManager:packScene before objects are destroyed.
-- Captures the current warehouse fuel levels so they can be restored on next deployment.
-- ====================================================================================================

metalFarpScene.onRepack = function(scene, repackData)
    local farpName = scene._params and scene._params.farpName
    if not farpName then return end
    local ab = Airbase.getByName(farpName)
    if not ab then return end
    local w = ab:getWarehouse()
    repackData.warehouseSnapshot = {
        liquid = {
            [0] = w:getLiquidAmount(0),   -- jet fuel
            [1] = w:getLiquidAmount(1),   -- aviation gasoline
            [2] = w:getLiquidAmount(2),   -- MW50
            [3] = w:getLiquidAmount(3),   -- diesel
        }
    }
end

-- ====================================================================================================
-- BLOCK 5 : self-registration
-- ====================================================================================================

CTLDSceneManager.getInstance():registerSceneModel(metalFarpScene)
