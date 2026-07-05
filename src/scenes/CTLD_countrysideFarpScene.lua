---@diagnostic disable
-- CTLD_countrysideFarpScene.lua
-- Countryside FARP deployment scene.
-- Lightweight forward arming/refueling point using an Invisible FARP heliport.
-- The Invisible FARP type creates a proper DCS airbase (warehouse, Airbase.getByName accessible)
-- without any visible F10 map label or 3D model — fully functional but discreet.
--
-- Layout (all offsets from trigger unit position):
--   Invisible FARP heliport — at unit position (distance=0)
--   4 Black Tyres           — corners of a 60×60 m landing square (immediate)
--   Fuel truck              — 40 m / 8°  heading 90° (under tent, t+5 s)
--   Repair truck            — 40 m / 11° heading 90° (under tent, t+5 s)
--   Tent                    — 40 m / 10° heading 90° (over trucks,  t+5.5 s)
--   Ammo cargo              — 35 m / 340°             (t+15 s)
--   Guards (infantry+MANPAD)— 32 m / 21°              (t+20 s)
--   M92 light panel         — 35 m / 349° alt+4 m    (t+25 s)
--   Windsock                — 31 m / 357°             (t+25 s)
--   Carrier Seaman          — 20 m / 0°   heading 180° (t+25 s)
--   Warehouse zeroed        — FARP warehouse emptied on completion (t+30 s)
--
-- Objects used (all in CTLDObjectRegistry):
--   Invisible_FARP, Fuel_Truck, repare_Truck, FARP_Tent,
--   ammo_cargo, CS_FARP_Guards, NF-2_LightOn, Windsock, us carrier shooter
--
-- Dependencies: CTLDObjectRegistry, CTLDSceneManager, CTLDUtils
-- ====================================================================================================

local countrysideFarpScene = {}
countrysideFarpScene.name  = "Countryside FARP"

-- Crate attributes -- auto-injected into CTLDCrateManager._weightIndex by _processSpawnableCrates().
countrysideFarpScene.crate = {
    weight         = 1001.24,
    i18nKey        = "Countryside FARP Crate",
    deployKey      = "Deploy Countryside FARP",
    groundKey      = "You must be on the ground to deploy a FARP.",
    cratesRequired = 3,
    side           = nil,
}

countrysideFarpScene.steps = {

    -- ----------------------------------------------------------------
    -- Step 1: Invisible FARP heliport (delay=0 — must be 0 to avoid
    -- double-count on first step).
    -- Invisible FARP creates a proper DCS airbase (warehouse, accessible
    -- via Airbase.getByName) without F10 label or 3D model.
    -- Saves the spawned airbase name for the warehouse-stocking step.
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 0, angle = 0 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey = "Invisible_FARP",
        func = function(ctx)
            if not ctx.spawnedObj then return false end
            ctx.scene._params.farpName = ctx.spawnedObj:getName()
            return true
        end,
    },

    -- ----------------------------------------------------------------
    -- Step 2: 4 Black Tyres at the corners of the FARP landing square
    -- (t0 + 0 s — same tick as FARP). Marks boundary immediately.
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            local halfSide = 30
            local h    = ctx.scene._refHdgRad
            local cx   = ctx.scene._refX
            local cz   = ctx.scene._refZ
            local cosH = math.cos(h)
            local sinH = math.sin(h)
            local cid  = ctx.scene._countryId

            local corners = {
                {  halfSide,  halfSide },
                {  halfSide, -halfSide },
                { -halfSide,  halfSide },
                { -halfSide, -halfSide },
            }
            for i, c in ipairs(corners) do
                local fwd, right = c[1], c[2]
                local wx = cx + fwd * cosH - right * sinH
                local wz = cz + fwd * sinH + right * cosH
                local sd = {
                    name          = "CS_FARP_Flag_" .. i,
                    type          = "Black_Tyre",
                    shape_name    = "H-tyre_B",
                    category      = "Fortifications",
                    x             = wx,
                    y             = wz,
                    heading       = 0,
                    start_time    = 0,
                    dead          = false,
                    transportable = { randomTransportable = false },
                }
                local ok, obj = pcall(coalition.addStaticObject, cid, sd)
                if ok and obj then
                    ctx.scene._spawnedObjs[#ctx.scene._spawnedObjs + 1] = obj
                end
            end
            return true
        end,
    },

    -- ----------------------------------------------------------------
    -- Step 3: Fuel truck — under tent (t0 + 5 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 40, angle = 8 },
        delayAfterPreviousStep   = 5,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "Fuel_Truck",
    },

    -- ----------------------------------------------------------------
    -- Step 4: Repair truck — under tent, same tick (t0 + 5 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 40, angle = 11 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "repare_Truck",
    },

    -- ----------------------------------------------------------------
    -- Step 5: Tent — over both trucks (t0 + 5.1 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 40, angle = 10 },
        delayAfterPreviousStep   = 0.1,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "FARP_Tent",
    },

    -- ----------------------------------------------------------------
    -- Step 6: Ammo cargo (t0 + 15 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 35, angle = 340 },
        delayAfterPreviousStep   = 5,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey = "ammo_cargo",
    },

    -- ----------------------------------------------------------------
    -- Step 7: Guards — 1 infantry + 1 MANPAD (t0 + 20 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 32, angle = 21 },
        delayAfterPreviousStep   = 5,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey = "CS_FARP_Guards",
    },

    -- ----------------------------------------------------------------
    -- Step 8: M92 light panel at tent height (t0 + 25 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 35, angle = 349 },
        delayAfterPreviousStep   = 5,
        relativeHeadingInDegrees = 310,
        relativeAltitudeInMeters = 4,
        registryKey = "NF-2_LightOn",
    },

    -- ----------------------------------------------------------------
    -- Step 9: Windsock near the light, same timing (t0 + 25 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 31, angle = 357 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 220,
        relativeAltitudeInMeters = 0,
        registryKey = "Windsock",
    },

    -- ----------------------------------------------------------------
    -- Step 10: Carrier Seaman on the landing zone (t0 + 25 s).
    -- ----------------------------------------------------------------
    {
        polar                    = { distance = 20, angle = 0 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 90,
        relativeAltitudeInMeters = 0,
        registryKey = "us carrier shooter",
    },

    -- ----------------------------------------------------------------
    -- Step 11: Stock warehouse + completion message (t0 + 30 s).
    -- Fills all fuel types in the FARP warehouse so aircraft can
    -- refuel/rearm at this forward point.
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 5,
        func = function(ctx)
            local farpName = ctx.scene._params and ctx.scene._params.farpName
            if farpName then
                local ab = Airbase.getByName(farpName)
                if ab then
                    local w = ab:getWarehouse()
                    -- Invisible FARP airbases (DCS built-in) return nil for getWarehouse().
                    -- Only mod-based helipad FARPs have an accessible warehouse.
                    if w then
                        -- If this is a redeployed FARP, restore the full snapshot; otherwise zero the warehouse.
                        local snap = ctx.scene._params.repackData
                                  and ctx.scene._params.repackData.warehouseSnapshot
                        if snap then
                            -- Liquids
                            for fuelType = 0, 3 do
                                w:setLiquidAmount(fuelType, snap.liquid and snap.liquid[fuelType] or 0)
                            end
                            -- Weapons: clear current, then set snapshot values
                            local cur = w:getInventory()
                            for typeName in pairs(cur and cur.weapon or {}) do
                                if not (snap.weapon and snap.weapon[typeName]) then
                                    w:setItem(typeName, 0)
                                end
                            end
                            for typeName, count in pairs(snap.weapon or {}) do
                                w:setItem(typeName, count)
                            end
                            -- Aircraft: clear current, then set snapshot values
                            for typeName in pairs(cur and cur.aircraft or {}) do
                                if not (snap.aircraft and snap.aircraft[typeName]) then
                                    w:setItem(typeName, 0)
                                end
                            end
                            for typeName, count in pairs(snap.aircraft or {}) do
                                w:setItem(typeName, count)
                            end
                        else
                            w:setLiquidAmount(0, 0)   -- jet fuel
                            w:setLiquidAmount(1, 0)   -- aviation gasoline
                            w:setLiquidAmount(2, 0)   -- MW50
                            w:setLiquidAmount(3, 0)   -- diesel
                        end
                    end
                end
            end
            trigger.action.outText(
                ctld.tr("--- Countryside FARP Deployment by %1 : Complete! ---", ctx.unit:getName()), 10)
            return true
        end,
    },
}

-- ====================================================================================================
-- BLOCK 1 : i18n -- 4 mandatory languages
-- ====================================================================================================

ctld.i18n["en"]["Countryside FARP Crate"]                                        = "Countryside FARP Crate"
ctld.i18n["fr"]["Countryside FARP Crate"]                                        = "Caisse FARP Campagne"
ctld.i18n["es"]["Countryside FARP Crate"]                                        = "Caja FARP Campo"
ctld.i18n["ko"]["Countryside FARP Crate"]                                        = "야외 FARP 화물"

ctld.i18n["en"]["Deploy Countryside FARP"]                                       = "Deploy Countryside FARP"
ctld.i18n["fr"]["Deploy Countryside FARP"]                                       = "Déployer FARP Campagne"
ctld.i18n["es"]["Deploy Countryside FARP"]                                       = "Desplegar FARP Campo"
ctld.i18n["ko"]["Deploy Countryside FARP"]                                       = "야외 FARP 배치"

ctld.i18n["en"]["--- Countryside FARP Deployment by %1 : Complete! ---"]         = "--- Countryside FARP Deployment by %1 : Complete! ---"
ctld.i18n["fr"]["--- Countryside FARP Deployment by %1 : Complete! ---"]         = "--- Déploiement FARP Campagne par %1 : Terminé ! ---"
ctld.i18n["es"]["--- Countryside FARP Deployment by %1 : Complete! ---"]         = "--- Despliegue FARP Campo por %1 : ¡Completo! ---"
ctld.i18n["ko"]["--- Countryside FARP Deployment by %1 : Complete! ---"]         = "--- %1에 의한 야외 FARP 배치 완료! ---"

-- ====================================================================================================
-- BLOCK 2 : Registry entries required by this scene.
-- registerIfAbsent() is a no-op when the key already exists, so multiple scenes
-- can safely declare the same shared entry (FARP, Fuel_Truck, etc.) without conflict.
-- ====================================================================================================

CTLDObjectRegistry.registerIfAbsent("Invisible_FARP", {
    groupType            = "STATIC",
    namePrefix           = "CS_FARP",
    type                 = "Invisible FARP",
    shape_name           = "invisiblefarp",
    category             = "Heliports",
    heliport_frequency   = "127.5",
    heliport_callsign_id = 1,
    heliport_modulation  = 0,
    rate                 = 100,
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

CTLDObjectRegistry.registerIfAbsent("CS_FARP_Guards", {
    groupType  = "GROUND",
    namePrefix = "CS_FARP_Guard_Grp",
    task       = "Ground Nothing",
    category   = Unit.Category.GROUND_UNIT,
    units = {
        {
            namePrefix     = "CS_Guard_Infantry",
            unitType       = function(cid)
                return cid == coalition.side.RED and "Infantry AK" or "Soldier M4"
            end,
            playerCanDrive = false,
            dx = 0, dz = 0, dh = 0,
        },
        {
            namePrefix     = "CS_Guard_Manpad",
            unitType       = function(cid)
                return cid == coalition.side.RED and "SA-18 Igla manpad" or "Soldier stinger"
            end,
            playerCanDrive = false,
            dx = 3, dz = 0, dh = 0,
        },
    },
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
-- BLOCK : onRepack — called by CTLDSceneManager:packScene before objects are destroyed.
-- Captures the current warehouse fuel levels so they can be restored on next deployment.
-- ====================================================================================================

countrysideFarpScene.onRepack = function(scene, repackData)
    local farpName = scene._params and scene._params.farpName
    if not farpName then return end
    local ab = Airbase.getByName(farpName)
    if not ab then return end
    local w = ab:getWarehouse()
    if not w then return end   -- Invisible FARP has no warehouse
    local inv = w:getInventory()
    repackData.warehouseSnapshot = {
        liquid = {
            [0] = w:getLiquidAmount(0),   -- jet fuel
            [1] = w:getLiquidAmount(1),   -- aviation gasoline
            [2] = w:getLiquidAmount(2),   -- MW50
            [3] = w:getLiquidAmount(3),   -- diesel
        },
        weapon   = inv and inv.weapon   or {},
        aircraft = inv and inv.aircraft or {},
    }
end

-- ====================================================================================================
-- Self-registration
-- ====================================================================================================

CTLDSceneManager.getInstance():registerSceneModel(countrysideFarpScene)
