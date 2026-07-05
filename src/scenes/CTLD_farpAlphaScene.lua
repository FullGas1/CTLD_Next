---@diagnostic disable
-- CTLD_farpAlphaScene.lua
-- FARP Alpha deployment scene — standard forward arming/refueling point.
-- Migrated from CTLDSceneManager._FARP_ALPHA_SCENE (was in CTLD_sceneManager.lua).
--
-- Layout (all offsets from trigger unit position):
--   SINGLE_HELIPAD heliport — 100 m ahead at 0°
--   Command tent            — 130 m / 5°   heading 90° (t+3 s)
--   Ammo storage            — 110 m / 340°             (t+6 s)
--   Fuel truck              — 110 m / 15°              (t+11 s)
--   Repair truck            — 125 m / 15°              (t+16 s)
--   Security guard group    — 90  m / 15°              (t+16 s)
--   Barrels cargo           — 100 m / 350°             (t+19 s)
--   Cargo box               — 98  m / 350.2°           (t+22 s)
--   Ammo cargo              — 108 m / 351.2°           (t+25 s)
--   Ammo cargo 2            — 109.5 m / 351.3°         (t+28 s)
--   Carrier shooter static  — 115 m / 5°               (t+31 s)
--   Light panel             — 116.7 m / 353°           (t+34 s)
--   Windsock                — 80 m / 10°               (t+37 s)
--   Completion message      — func-only                (t+37 s)
--
-- Objects used (all in CTLDObjectRegistry):
--   SINGLE_HELIPAD, FARP_Tent, FARP_Ammo_Storage, Fuel_Truck, repare_Truck,
--   FARP_Security_Guard, barrels_cargo, Cargo06, ammo_cargo,
--   us carrier shooter, NF-2_LightOn, Windsock
--
-- Dependencies: CTLDObjectRegistry, CTLDSceneManager, CTLDUtils
-- ====================================================================================================

-- ====================================================================================================
-- BLOCK 1 : i18n -- 4 mandatory languages
-- ====================================================================================================

ctld.i18n["en"]["FARP Alpha Crate"]                                  = "FARP Alpha Crate"
ctld.i18n["fr"]["FARP Alpha Crate"]                                  = "Caisse FARP Alpha"
ctld.i18n["es"]["FARP Alpha Crate"]                                  = "Caja FARP Alpha"
ctld.i18n["ko"]["FARP Alpha Crate"]                                  = "FARP 알파 화물"

ctld.i18n["en"]["Deploy FARP Alpha"]                                 = "Deploy FARP Alpha"
ctld.i18n["fr"]["Deploy FARP Alpha"]                                 = "Déployer FARP Alpha"
ctld.i18n["es"]["Deploy FARP Alpha"]                                 = "Desplegar FARP Alpha"
ctld.i18n["ko"]["Deploy FARP Alpha"]                                 = "FARP 알파 배치"

ctld.i18n["en"]["--- FARP Dynamic Deployment by %1 : Complete! ---"] = "--- FARP Dynamic Deployment by %1 : Complete! ---"
ctld.i18n["fr"]["--- FARP Dynamic Deployment by %1 : Complete! ---"] = "--- Déploiement FARP Dynamique par %1 : Terminé ! ---"
ctld.i18n["es"]["--- FARP Dynamic Deployment by %1 : Complete! ---"] = "--- Despliegue FARP Dinámico por %1 : ¡Completo! ---"
ctld.i18n["ko"]["--- FARP Dynamic Deployment by %1 : Complete! ---"] = "--- %1에 의한 FARP 동적 배치 완료! ---"

-- ====================================================================================================
-- BLOCK 2 : ObjectRegistry entries required by this scene (registerIfAbsent = no-op si déjà présente)
-- ====================================================================================================

CTLDObjectRegistry.registerIfAbsent("SINGLE_HELIPAD", {
    groupType            = "STATIC",
    namePrefix           = "SINGLE_HELIPAD",
    type                 = "SINGLE_HELIPAD",
    category             = "Heliports",
    shape_name           = "FARP",
    heliport_frequency   = "127.5",
    heliport_callsign_id = 1,
    heliport_modulation  = 0,
})

CTLDObjectRegistry.registerIfAbsent("FARP_Tent", {
    groupType  = "STATIC",
    namePrefix = "FARP_Tent",
    type       = "FARP Tent",
    category   = "Fortifications",
})

CTLDObjectRegistry.registerIfAbsent("FARP_Ammo_Storage", {
    groupType  = "STATIC",
    namePrefix = "FARP_Ammo_Storage",
    type       = "FARP Ammo Dump Coating",
    category   = "Fortifications",
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

CTLDObjectRegistry.registerIfAbsent("FARP_Security_Guard", {
    groupType  = "GROUND",
    namePrefix = "FARP_Guard_Grp",
    task       = "Ground Nothing",
    category   = Unit.Category.GROUND_UNIT,
    units = {
        {
            namePrefix     = "Guard_Infantry",
            unitType       = function(cid)
                return cid == coalition.side.RED and "Infantry AK" or "Soldier M4"
            end,
            playerCanDrive = false,
            dx = 0, dz = 0, dh = 0,
        },
        {
            namePrefix     = "Guard_Infantry",
            unitType       = function(cid)
                return cid == coalition.side.RED and "Infantry AK" or "Soldier M4"
            end,
            playerCanDrive = false,
            dx = 3, dz = 1, dh = 0.610865,
        },
        {
            namePrefix     = "Guard_Manpad",
            unitType       = function(cid)
                return cid == coalition.side.RED and "SA-18 Igla manpad" or "Soldier stinger"
            end,
            playerCanDrive = false,
            dx = -3, dz = -1, dh = -0.610865,
        },
    },
})

CTLDObjectRegistry.registerIfAbsent("barrels_cargo", {
    groupType  = "STATIC",
    namePrefix = "barrels_cargo",
    type       = "barrels_cargo",
    category   = "Cargos",
    shape_name = "barrels_cargo",
    rate       = 100,
})

CTLDObjectRegistry.registerIfAbsent("Cargo06", {
    groupType  = "STATIC",
    namePrefix = "ammo_box06",
    type       = "Cargo06",
    category   = "Cargos",
    shape_name = "M92_Cargo06",
    rate       = 1,
})

CTLDObjectRegistry.registerIfAbsent("ammo_cargo", {
    groupType  = "STATIC",
    namePrefix = "ammo_box_cargo",
    type       = "ammo_cargo",
    category   = "Cargos",
    shape_name = "ammo_box_cargo",
    rate       = 1,
})

CTLDObjectRegistry.registerIfAbsent("us carrier shooter", {
    groupType  = "STATIC",
    namePrefix = "carrier_shooter",
    type       = "us carrier shooter",
    category   = "Personnel",
    shape_name = "carrier_shooter",
    livery_id  = "blue",
    rate       = 20,
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

-- ====================================================================================================
-- BLOCK 3 : scene definition + crate attributes
-- ====================================================================================================

local farpAlphaScene = {
    name = "FARP Alpha",

    -- Crate attributes -- auto-injected into CTLDCrateManager._weightIndex by _processSpawnableCrates().
    crate = {
        weight         = 1001.23,
        i18nKey        = "FARP Alpha Crate",
        deployKey      = "Deploy FARP Alpha",
        groundKey      = "You must be on the ground to deploy a FARP.",
        cratesRequired = 1,
        side           = nil,
        showSets       = false,
    },

    steps = {

        -- Step 1: FARP helipad (STATIC) — warehouse stocked with all fuel types after spawn.
        {
            polar                    = { distance = 100, angle = 0 },
            delayAfterPreviousStep   = 0,
            relativeHeadingInDegrees = 180,
            relativeAltitudeInMeters = 0,
            registryKey = "SINGLE_HELIPAD",
            func = function(ctx)
                if not ctx.spawnedObj then return false end
                local ab = Airbase.getByName(ctx.spawnedObj:getName())
                if ab then
                    local w = ab:getWarehouse()
                    w:addLiquid(0, 10000)   -- jet fuel
                    w:addLiquid(1, 10000)   -- aviation gasoline
                    w:addLiquid(2, 10000)   -- MW50
                    w:addLiquid(3, 10000)   -- diesel
                end
                return true
            end,
        },

        -- Step 2: Command tent (STATIC)
        {
            polar                    = { distance = 130, angle = 5 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 90,
            relativeAltitudeInMeters = 0,
            registryKey = "FARP_Tent",
        },

        -- Step 3: Ammo storage (STATIC)
        {
            polar                    = { distance = 110, angle = 340 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 0,
            relativeAltitudeInMeters = 0,
            registryKey = "FARP_Ammo_Storage",
        },

        -- Step 4a: Fuel truck (GROUND)
        {
            polar                    = { distance = 110, angle = 15 },
            delayAfterPreviousStep   = 5,
            relativeHeadingInDegrees = 0,
            relativeAltitudeInMeters = 0,
            registryKey = "Fuel_Truck",
        },

        -- Step 4b: Repair truck (GROUND)
        {
            polar                    = { distance = 125, angle = 15 },
            delayAfterPreviousStep   = 5,
            relativeHeadingInDegrees = 0,
            relativeAltitudeInMeters = 0,
            registryKey = "repare_Truck",
        },

        -- Step 5: Security guard group (GROUND)
        {
            polar                    = { distance = 90, angle = 15 },
            delayAfterPreviousStep   = 0,
            relativeHeadingInDegrees = 0,
            relativeAltitudeInMeters = 0,
            registryKey = "FARP_Security_Guard",
        },

        -- Step 6a: Barrels (STATIC)
        {
            polar                    = { distance = 100, angle = 350 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 0,
            relativeAltitudeInMeters = 0,
            registryKey = "barrels_cargo",
        },

        -- Step 6b1: Cargo box (STATIC)
        {
            polar                    = { distance = 98, angle = 350.2 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 90,
            relativeAltitudeInMeters = 0,
            registryKey = "Cargo06",
        },

        -- Step 6b2: Ammo cargo (STATIC)
        {
            polar                    = { distance = 108, angle = 351.2 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 90,
            relativeAltitudeInMeters = 0,
            registryKey = "ammo_cargo",
        },

        -- Step 6c: Ammo cargo 2 (STATIC)
        {
            polar                    = { distance = 109.5, angle = 351.3 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 95,
            relativeAltitudeInMeters = 0,
            registryKey = "ammo_cargo",
        },

        -- Step 6d: Carrier shooter static (STATIC)
        {
            polar                    = { distance = 115, angle = 5 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 220,
            relativeAltitudeInMeters = 0,
            registryKey = "us carrier shooter",
        },

        -- Step 6e: Light panel (STATIC)
        {
            polar                    = { distance = 116.7, angle = 353 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 220,
            relativeAltitudeInMeters = 0,
            registryKey = "NF-2_LightOn",
        },

        -- Step 6f: Windsock (STATIC)
        {
            polar                    = { distance = 80, angle = 10 },
            delayAfterPreviousStep   = 3,
            relativeHeadingInDegrees = 220,
            relativeAltitudeInMeters = 0,
            registryKey = "Windsock",
        },

        -- Step 7: Completion message (func-only)
        {
            delayAfterPreviousStep = 0,
            func = function(ctx)
                trigger.action.outText(
                    ctld.tr("--- FARP Dynamic Deployment by %1 : Complete! ---", ctx.unit:getName()), 10)
                return true
            end,
        },
    },
}

-- ====================================================================================================
-- BLOCK 4 : self-registration (always last)
-- ====================================================================================================

CTLDSceneManager.getInstance():registerSceneModel(farpAlphaScene)
