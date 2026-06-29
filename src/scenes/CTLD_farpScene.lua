---@diagnostic disable
-- CTLD_farpScene.lua
-- FARP deployment scene — spawns a functional Forward Arming and Refueling Point.
--
-- Reference point: 50 m at 12 o'clock from the trigger unit (prescript step 0).
-- All subsequent object offsets are relative to that reference point.
--
-- Objects registered (all in CTLDObjectRegistry):
--   SINGLE_HELIPAD    — landing pad (logistic zone anchor)     at ref point
--   FARP_Tent         — crew tent                              30 m / 90°
--   FARP_Ammo_Storage — ammunition dump                        30 m / 135°
--   Windsock          — wind indicator / logistic unit marker  15 m / 270°
--   Fuel_Truck        — coalition-aware fuel truck             35 m / 225°
--
-- Dependencies: CTLDObjectRegistry, CTLDSceneManager, CTLDUtils
-- ====================================================================================================

local farpScene = {}
farpScene.name = "farpScene"

farpScene.steps = {

    -- ----------------------------------------------------------------
    -- Step 0: prescript — move reference point 50 m ahead of the heli.
    -- All subsequent polar offsets are relative to this new origin.
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            local hdg = ctld.utils.getHeadingInRadians("farpScene.prescript", ctx.unit, true)
            local pt  = ctx.unit:getPoint()
            local fx  = pt.x + math.cos(hdg) * 50
            local fz  = pt.z + math.sin(hdg) * 50
            ctx.scene._refX   = fx
            ctx.scene._refZ   = fz
            ctx.scene._refAlt = land.getHeight({ x = fx, y = fz })
        end,
    },

    -- ----------------------------------------------------------------
    -- Step 1: FARP helipad — at the reference point.
    -- ----------------------------------------------------------------
    {
        registryKey              = "SINGLE_HELIPAD",
        polar                    = { distance = 0, angle = 0 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
    },

    -- ----------------------------------------------------------------
    -- Step 2: Command tent — 30 m right of helipad.
    -- ----------------------------------------------------------------
    {
        registryKey              = "FARP_Tent",
        polar                    = { distance = 30, angle = 90 },
        delayAfterPreviousStep   = 1,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
    },

    -- ----------------------------------------------------------------
    -- Step 3: Ammo storage — 30 m at 135° from helipad.
    -- ----------------------------------------------------------------
    {
        registryKey              = "FARP_Ammo_Storage",
        polar                    = { distance = 30, angle = 135 },
        delayAfterPreviousStep   = 1,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
    },

    -- ----------------------------------------------------------------
    -- Step 4: Windsock — 15 m left of helipad.
    -- ----------------------------------------------------------------
    {
        registryKey              = "Windsock",
        polar                    = { distance = 15, angle = 270 },
        delayAfterPreviousStep   = 1,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
    },

    -- ----------------------------------------------------------------
    -- Step 5: Fuel truck — 35 m at 225° from helipad.
    -- ----------------------------------------------------------------
    {
        registryKey              = "Fuel_Truck",
        polar                    = { distance = 35, angle = 225 },
        delayAfterPreviousStep   = 1,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
    },
}

-- ====================================================================================================
-- Self-registration
-- ====================================================================================================

CTLDSceneManager.getInstance():registerSceneModel(farpScene)
