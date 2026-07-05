---@diagnostic disable
-- ============================================================
-- CTLD_fobScene.lua
--
-- ============================================================
-- BLOCK 1 : i18n -- 4 mandatory languages
-- ============================================================

ctld.i18n["en"]["FOB Crate"]                                              = "FOB Crate"
ctld.i18n["fr"]["FOB Crate"]                                              = "Caisse FOB"
ctld.i18n["es"]["FOB Crate"]                                              = "Caja FOB"
ctld.i18n["ko"]["FOB Crate"]                                              = "FOB 화물"

ctld.i18n["en"]["Build FOB"]                                              = "Build FOB"
ctld.i18n["fr"]["Build FOB"]                                              = "Construire un FOB"
ctld.i18n["es"]["Build FOB"]                                              = "Construir FOB"
ctld.i18n["ko"]["Build FOB"]                                              = "FOB 건설"

ctld.i18n["en"]["FOB construction started by %1."]                        = "FOB construction started by %1."
ctld.i18n["fr"]["FOB construction started by %1."]                        = "Construction du FOB démarrée par %1."
ctld.i18n["es"]["FOB construction started by %1."]                        = "%1 inició la construcción del FOB."
ctld.i18n["ko"]["FOB construction started by %1."]                        = "%1(이)가 FOB 건설을 시작했습니다."

ctld.i18n["en"]["FOB 90% complete - final installation in progress..."]   = "FOB 90% complete - final installation in progress..."
ctld.i18n["fr"]["FOB 90% complete - final installation in progress..."]   = "FOB à 90 % — installation finale en cours..."
ctld.i18n["es"]["FOB 90% complete - final installation in progress..."]   = "FOB al 90% — instalación final en progreso..."
ctld.i18n["ko"]["FOB 90% complete - final installation in progress..."]   = "FOB 90% 완료 - 최종 설치 진행 중..."

ctld.i18n["en"]["FOB established by %1 - logistics hub now active."]      = "FOB established by %1 - logistics hub now active."
ctld.i18n["fr"]["FOB established by %1 - logistics hub now active."]      = "FOB établi par %1 - hub logistique opérationnel."
ctld.i18n["es"]["FOB established by %1 - logistics hub now active."]      = "FOB establecido por %1 - hub logístico ahora activo."
ctld.i18n["ko"]["FOB established by %1 - logistics hub now active."]      = "%1에 의해 FOB가 건설되었습니다 - 보급 기지가 활성화됩니다."

-- ============================================================
-- CTLD_fobScene.lua (suite)
-- FOB deployment scene — animated construction site (120 s).
--
-- The scene is self-timed: starts immediately when the FOB
-- manager calls playScene and completes in exactly 120 seconds.
-- No external buildTimeFOB pre-timer is required.
--
-- Construction statics (f1–f7, fh1–fh3) are mission-defined
-- TYPE REFERENCES placed anywhere in the test mission.
-- Their positions are ignored; only getTypeName() is used.
-- Each static is spawned at a fixed polar offset around the
-- FOB reference point defined in _STATIC_LAYOUT below.
-- If a type-ref static is absent the step is silently skipped.
--
-- Phase 1 (T+0 … T+63): 10 construction objects appear
--   progressively (f1–f7 materials, fh1–fh3 workers).
-- Phase 2 (T+77 … T+90): permanent FOB objects spawn
--   (container + watchtower).
-- Phase 3 (T+90 … T+120): construction statics removed in 5
--   pairs; completion message at exactly T+120.
--
-- Step timing (delayAfterPreviousStep = delay before NEXT step):
--   Step  1 (T+  0)  prescript — ref point + type-ref scan
--   Step  2 (T+  0)  spawn f1
--   Step  3 (T+  7)  spawn fh1
--   Step  4 (T+ 14)  spawn f2
--   Step  5 (T+ 21)  spawn f3
--   Step  6 (T+ 28)  spawn fh2
--   Step  7 (T+ 35)  spawn f4
--   Step  8 (T+ 42)  spawn f5
--   Step  9 (T+ 49)  spawn fh3
--   Step 10 (T+ 56)  spawn f6
--   Step 11 (T+ 63)  spawn f7
--   Step 12 (T+ 70)  progress message "90% complete"
--   Step 13 (T+ 77)  FOB container (permanent)
--   Step 14 (T+ 85)  FOB watchtower (permanent)
--   Step 15 (T+ 90)  cleanup group 1: f1 + fh1
--   Step 16 (T+ 95)  cleanup group 2: f2 + fh2
--   Step 17 (T+100)  cleanup group 3: f3 + f4
--   Step 18 (T+105)  cleanup group 4: f5 + fh3
--   Step 19 (T+110)  cleanup group 5: f6 + f7
--   Step 20 (T+120)  completion message — scene ends
--
-- ctx.scene._params expected keys (all optional):
--   centroid   vec3   pre-computed FOB reference position
--   player     string display name in messages
--
-- Dependencies: CTLDObjectRegistry, CTLDSceneManager, CTLDUtils
-- DCS API: coalition.addStaticObject, StaticObject.getByName,
--          land.getHeight, trigger.action.outTextForCoalition
-- ============================================================

-- ============================================================
-- BLOCK 2 : ObjectRegistry entries required by this scene
-- ============================================================

CTLDObjectRegistry.registerIfAbsent("FOB_container", {
    groupType  = "STATIC",
    namePrefix = "FOB_Outpost",
    type       = "outpost",
    category   = "Fortifications",
    canCargo   = false,
})

CTLDObjectRegistry.registerIfAbsent("FOB_watchtower", {
    groupType  = "STATIC",
    namePrefix = "FOB_Watchtower",
    type       = "house2arm",
    category   = "Fortifications",
    canCargo   = false,
    rate       = 100,
})

-- ============================================================
-- BLOCK 3 : scene definition + crate attributes
-- ============================================================

local fobScene = {}
fobScene.name = "FOB"

-- Crate attributes -- auto-injected into CTLDCrateManager._weightIndex.
-- L'action unpack délègue à CTLDFOBManager:unpackFOBCrates() qui gère les
-- guards (logistic zone, distance, crate count) and the onComplete callback.
fobScene.crate = {
    weight         = 1001.22,
    i18nKey        = "FOB Crate",
    deployKey      = "Build FOB",
    cratesRequired = 3,
    side           = nil,
    showSets       = false,
    -- fobCompatible: marks this scene as a FOB-type deployment.
    -- CTLDFOBManager._collectFOBCrates() collects any crate whose scene model
    -- has fobCompatible=true, so future FOB variants are recognised automatically.
    fobCompatible  = true,
    -- Custom unpack: fully delegates to CTLDFOBManager (guards + crate consumption + playScene).
    -- sceneName identifies this specific FOB variant so multi-FOB missions work correctly.
    unpack = function(unit, unitName, sceneName)
        CTLDFOBManager.getInstance():unpackFOBCrates(unit, unitName, sceneName)
    end,
}

-- ----------------------------------------------------------------
-- Some DCS types require an explicit shape_name for coalition.addStaticObject
-- (e.g. carrier personnel). getDesc() does not expose it at runtime,
-- so known shapes are listed here as a fallback.
-- ----------------------------------------------------------------
local _SHAPE_NAME = {
    ["Carrier Seaman"]           = "carrier_seaman_USA",
    ["Carrier LSO Personell 1"]  = "carrier_lso1_usa",
    ["Carrier LSO Personell 2"]  = "carrier_lso2_usa",
}

-- ----------------------------------------------------------------
-- Polar layout of construction statics around the FOB centre.
-- angle_deg : 0° = 12 o'clock (heading forward), CW.
-- dist_m    : metres from FOB reference point.
-- ----------------------------------------------------------------
local _STATIC_LAYOUT = {
    f1  = { angle =   0, dist = 28 },             -- 12 o'clock — landmark (crane / tower)
    fh1 = { angle =  90, dist = 22, hdgDeg =  90 }, -- E — worker faces E (toward Tower Crane)
    f2  = { angle =  60, dist = 22 },             -- NE — materials
    f3  = { angle =  90, dist = 28 },             -- 3 o'clock — Tower Crane
    fh2 = { angle = 210, dist = 24, hdgDeg = 210 }, -- SSW — worker faces SSW (toward Camouflage06)
    f4  = { angle = 180, dist = 25 },             -- 6 o'clock — materials
    f5  = { angle = 205, dist = 31 },             -- SSW — Camouflage06 tent
    fh3 = { angle = 265, dist = 22, hdgDeg = 265 }, -- W — worker faces W (toward Cargo05)
    f6  = { angle = 270, dist = 28 },             -- 9 o'clock — materials
    f7  = { angle = 315, dist = 20 },             -- NW — materials
}

-- Ordered scan list (only for prescript type-read loop)
local _STATIC_NAMES = {"f1","f2","f3","f4","f5","f6","f7","fh1","fh2","fh3"}

-- ----------------------------------------------------------------
-- Prescript helper: read getTypeName() from each mission type-ref
-- static.  Position is irrelevant — only the type is stored.
-- ----------------------------------------------------------------
local function _initMissionStatics(ctx)
    ctx.scene._staticTypes  = {}
    ctx.scene._staticShapes = {}
    ctx.scene._namedTempObjs = {}
    for _, name in ipairs(_STATIC_NAMES) do
        -- Type-refs may be placed as StaticObjects or as Units (group members).
        local s = StaticObject.getByName(name)
        if not (s and s:isExist()) then
            s = Unit.getByName(name)
        end
        if s and s:isExist() then
            ctx.scene._staticTypes[name] = s:getTypeName()
            -- shape_name: try getDesc() first, fall back to known-type table.
            local ok_d, desc = pcall(function() return s:getDesc() end)
            local shapeName = (ok_d and desc) and (desc.shapeName or desc.shape_name) or nil
            ctx.scene._staticShapes[name] = shapeName or _SHAPE_NAME[ctx.scene._staticTypes[name]]
            ctld.utils.log("INFO", "fobScene: type-ref '%s' → '%s' shape=%s",
                name, ctx.scene._staticTypes[name],
                tostring(ctx.scene._staticShapes[name]))
        else
            ctld.utils.log("WARN",
                "fobScene: type-ref '%s' not found (static nor unit) — step skipped", name)
        end
    end
end

-- ----------------------------------------------------------------
-- Spawn a construction static at its polar position around the
-- FOB reference point, using the type read from the mission.
-- Tracked by name in _namedTempObjs for targeted cleanup.
-- ----------------------------------------------------------------
local function _spawnMissionStatic(ctx, name)
    local typeName = ctx.scene._staticTypes and ctx.scene._staticTypes[name]
    local layout   = _STATIC_LAYOUT[name]
    if not typeName or not layout then return end

    local absAngle   = ctx.scene._refHdgRad + math.rad(layout.angle)
    local nx         = ctx.scene._refX + math.cos(absAngle) * layout.dist
    local ez         = ctx.scene._refZ + math.sin(absAngle) * layout.dist
    local uid        = ctld.utils.getNextUniqId()
    local shapeName  = ctx.scene._staticShapes and ctx.scene._staticShapes[name]
    local descriptor = {
        name          = "FOB_tmp_" .. uid,
        type          = typeName,
        x             = nx,
        y             = ez,
        heading       = ctx.scene._refHdgRad + math.rad(layout.hdgDeg or 0),
        start_time    = 0,
        transportable = { randomTransportable = false },
    }
    if shapeName then descriptor.shape_name = shapeName end
    local ok, obj = ctld.utils.spawnAs("STATIC", ctx.scene._countryId, descriptor)
    if ok and obj then
        ctx.scene._namedTempObjs[name] = obj
        ctld.utils.log("INFO",
            "fobScene: spawned '%s' (%s) angle=%.0f dist=%.0f at (%.0f, %.0f)",
            name, typeName, layout.angle, layout.dist, nx, ez)
    else
        ctld.utils.log("WARN",
            "fobScene: spawn failed '%s' (%s): %s", name, typeName, tostring(obj))
    end
end

-- ----------------------------------------------------------------
-- Destroy one named temporary static (safe, no-throw).
-- ----------------------------------------------------------------
local function _destroyNamed(ctx, name)
    local obj = ctx.scene._namedTempObjs and ctx.scene._namedTempObjs[name]
    if obj then
        pcall(function()
            if obj:isExist() then obj:destroy() end
        end)
        ctx.scene._namedTempObjs[name] = nil
    end
end

-- ============================================================
-- Scene steps
-- ============================================================

fobScene.steps = {

    -- ----------------------------------------------------------------
    -- Step 1 (T+0): prescript — set reference point, scan type-ref
    --   statics, announce construction start.
    -- delay=0 → step 2 fires immediately at T+0.
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            local centroid = ctx.scene._params and ctx.scene._params.centroid
            if centroid then
                ctx.scene._refX   = centroid.x
                ctx.scene._refZ   = centroid.z
                ctx.scene._refAlt = centroid.y
            else
                local pt  = ctx.unit:getPoint()
                local hdg = ctld.utils.getHeadingInRadians("fobScene.prescript", ctx.unit, true)
                local fx  = pt.x + math.cos(hdg) * 100
                local fz  = pt.z + math.sin(hdg) * 100
                ctx.scene._refX   = fx
                ctx.scene._refZ   = fz
                ctx.scene._refAlt = land.getHeight({ x = fx, y = fz })
            end

            _initMissionStatics(ctx)

            local player = (ctx.scene._params and ctx.scene._params.player)
                           or ctx.unit:getName()
            trigger.action.outTextForCoalition(
                ctx.scene._coalitionId,
                ctld.tr("FOB construction started by %1.", player), 10)
        end,
    },

    -- Step 2 (T+0): f1 — Sandbag_09 (0° / 28 m).
    -- delay=7 → T+7.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "f1") end },

    -- Step 3 (T+7): f2 — Pile of Woods (60° / 22 m).
    -- delay=7 → T+14.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "f2") end },

    -- Step 4 (T+14): fh1 — worker, appears just before Tower Crane (90° / 22 m).
    -- delay=7 → T+21.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "fh1") end },

    -- Step 5 (T+21): f3 — Tower Crane (90° / 28 m).
    -- delay=7 → T+28.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "f3") end },

    -- Step 6 (T+28): f4 — Oil Barrel (180° / 25 m).
    -- delay=7 → T+35.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "f4") end },

    -- Step 7 (T+35): fh2 — worker, appears just before Camouflage06 (210° / 24 m).
    -- delay=7 → T+42.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "fh2") end },

    -- Step 8 (T+42): f5 — Camouflage06 tent (205° / 31 m).
    -- delay=7 → T+49.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "f5") end },

    -- Step 9 (T+49): fh3 — worker, appears just before Cargo05 (265° / 22 m).
    -- delay=7 → T+56.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "fh3") end },

    -- Step 10 (T+56): f6 — Cargo05 (270° / 28 m).
    -- delay=7 → T+63.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "f6") end },

    -- Step 11 (T+63): f7 — Sandbag_04 (315° / 20 m).
    -- delay=7 → T+70.
    { delayAfterPreviousStep = 7,
      func = function(ctx) _spawnMissionStatic(ctx, "f7") end },

    -- ----------------------------------------------------------------
    -- Step 12 (T+70): Progress message — "90% complete".
    -- delay=7 → FOB container at T+77.
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 7,
        func = function(ctx)
            trigger.action.outTextForCoalition(
                ctx.scene._coalitionId,
                ctld.tr("FOB 90% complete - final installation in progress..."), 10)
        end,
    },

    -- ----------------------------------------------------------------
    -- Step 13 (T+77): FOB outpost container (PERMANENT).
    -- delay=8 → watchtower at T+85.
    -- ----------------------------------------------------------------
    {
        registryKey              = "FOB_container",
        polar                    = { distance = 10, angle = 0 },
        delayAfterPreviousStep   = 8,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
    },

    -- ----------------------------------------------------------------
    -- Step 14 (T+85): FOB watchtower (PERMANENT).
    -- delay=5 → first cleanup at T+90.
    -- ----------------------------------------------------------------
    {
        registryKey              = "FOB_watchtower",
        polar                    = { distance = 39, angle = 158 },
        delayAfterPreviousStep   = 5,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
    },

    -- Step 15 (T+90): Cleanup 1 — f1 + fh1. delay=5 → T+95.
    { delayAfterPreviousStep = 5,
      func = function(ctx) _destroyNamed(ctx,"f1") ; _destroyNamed(ctx,"fh1") end },

    -- Step 16 (T+95): Cleanup 2 — f2 + fh2. delay=5 → T+100.
    { delayAfterPreviousStep = 5,
      func = function(ctx) _destroyNamed(ctx,"f2") ; _destroyNamed(ctx,"fh2") end },

    -- Step 17 (T+100): Cleanup 3 — f3 + f4. delay=5 → T+105.
    { delayAfterPreviousStep = 5,
      func = function(ctx) _destroyNamed(ctx,"f3") ; _destroyNamed(ctx,"f4") end },

    -- Step 18 (T+105): Cleanup 4 — f5 + fh3. delay=5 → T+110.
    { delayAfterPreviousStep = 5,
      func = function(ctx) _destroyNamed(ctx,"f5") ; _destroyNamed(ctx,"fh3") end },

    -- Step 19 (T+110): Cleanup 5 — f6 + f7. delay=10 → T+120.
    { delayAfterPreviousStep = 10,
      func = function(ctx) _destroyNamed(ctx,"f6") ; _destroyNamed(ctx,"f7") end },

    -- ----------------------------------------------------------------
    -- Step 20 (T+120): Completion message.
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            local player = (ctx.scene._params and ctx.scene._params.player)
                           or ctx.unit:getName()
            trigger.action.outTextForCoalition(
                ctx.scene._coalitionId,
                ctld.tr("FOB established by %1 - logistics hub now active.", player),
                10)
        end,
    },

    -- ----------------------------------------------------------------
    -- Step 21 (T+120): Register FOB — logistic zone, beacon, event.
    -- Runs immediately after step 20 (delay=0).
    -- Works for both F10 player flow and parachute auto-unpack:
    -- all required data is in ctx.scene._params (set by caller).
    -- ----------------------------------------------------------------
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            CTLDFOBManager.getInstance():_registerDeployedFOB(ctx.scene)
        end,
    },
}

-- ============================================================
-- BLOCK 4 : self-registration (always last)
-- ============================================================

CTLDSceneManager.getInstance():registerSceneModel(fobScene)
