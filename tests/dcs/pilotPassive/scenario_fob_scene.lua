---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_fob_scene.lua
-- PT6 — FOB scene visual validation
--
-- Steps:
--   Step 1 — cleanup + spawn 3 FOB crates devant l'hélico
--             + déclenchement automatique de unpackFOBCrates après 2 s
--   Step 2 — (injecter à ~T+130) vérification FOB enregistré dans CTLDFOBManager
--   Step 99 — résumé final
--
-- Prérequis :
--   • Slot UH-1H BLUE occupé, hélico au sol
--   • Position hélico à > 500 m de toute zone logistique existante
--     (sinon la guard _isTooCloseToZone bloque le build)
--   • enable_debug.lua injecté avant ce script
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FOB-SCN] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local TAG      = "[FOB-SCN]"
local STEP_VAR = "_FOB_SCN_STEP"

-- ── HEADER — affiché à chaque injection ───────────────────────────────────────
trigger.action.outText(
    "[FOB-SCN] === PT6 : FOB Scene validation ===\n"
    .. "PRE : UH-1H BLUE au sol, > 500 m de toute zone logistique\n"
    .. "      Statics f1-f7 + fh1-fh3 placés dans la mission\n"
    .. "RUN : 1) Injecter => 3 crates spawn + unpack auto dans 2 s\n"
    .. "      2) Observer animation 120 s (spawn progressif + FOB + cleanup)\n"
    .. "      3) Re-injecter a T+130 => verification FOB enregistre",
    30)

-- ── helpers ───────────────────────────────────────────────────────────────────

local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 40)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end

local function pass(msg)
    report("[PASS] " .. msg)
end

local function fail(msg)
    report("[FAIL] " .. msg)
    error(msg)
end

local function check(id, desc, cond, detail)
    if cond then
        pass(id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (detail and (" | " .. detail) or ""))
    end
end

-- ── init debug ────────────────────────────────────────────────────────────────

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]             = true
cfg.settings["debugScreenLog"]    = false
cfg.settings["debugScreenLogDuration"] = 12

-- ── state machine ─────────────────────────────────────────────────────────────

_G[STEP_VAR] = _G[STEP_VAR] or 1
local step = _G[STEP_VAR]

report("==== START " .. os.date("%H:%M:%S") .. " | step=" .. step .. " ====")

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Spawn 3 FOB crates + unpack automatique à T+2
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    ctld_test.cleanup()

    local transport = ctld_test.getTransport()
    if not transport then fail("aucun joueur BLUE") end

    local playerName = transport:getName()
    local pPos       = transport:getPoint()
    local hdg        = ctld.utils.getHeadingInRadians("fob_scn", transport, true)
    local cId        = transport:getCoalition()

    -- Cleanup FOBs existants (objets permanents + beacon + zones logistiques + registry)
    local fobMgr       = CTLDFOBManager.getInstance()
    local beaconMgr    = CTLDBeaconManager.getInstance()
    local existingFobs = fobMgr:getFOBsForCoalition(cId)
    for _, fob in ipairs(existingFobs) do
        -- Objets permanents de scene
        for _, obj in ipairs(fob.sceneObjects) do
            if obj then pcall(function() if obj:isExist() then obj:destroy() end end) end
        end
        -- Beacon radio FOB
        if fob.beacon then
            local bn = fob.beacon.beaconName
            if beaconMgr._beacons[bn] then
                pcall(function() beaconMgr:_destroyBeaconUnits(fob.beacon) end)
                pcall(function() beaconMgr:_freeFrequencies(fob.beacon) end)
                pcall(function() beaconMgr:_removeBeaconFromLayers(fob.beacon) end)
                beaconMgr._beacons[bn] = nil
                report("Purge beacon: " .. bn)
            end
        end
        -- Zone logistique
        pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(fob.name) end)
        fobMgr._fobs[fob.fobId] = nil
        report("Purge FOB: " .. fob.name)
    end
    fobMgr._objectToFOB = {}

    -- Nettoyage des crates FOB résiduelles de la session précédente
    local cm       = CTLDCrateManager.getInstance()
    local leftover = cm:getCratesInRange(pPos, 750)
    local purged   = 0
    for _, c in ipairs(leftover) do
        if c.coalition == cId and c.descriptor and c.descriptor.unit == "FOB" then
            cm:destroyCrate(c.crateName)
            purged = purged + 1
        end
    end
    if purged > 0 then
        report("Purge : " .. purged .. " crate(s) FOB residuelle(s)")
    end

    -- Descriptor FOB (unit = "FOB", cratesRequired = 3)
    local fobDesc = cm:findDescriptorByUnitType("FOB")
    check("F-SCN.1", "FOB descriptor present dans config", fobDesc ~= nil)

    local required = (fobDesc and fobDesc.cratesRequired) or 3

    -- Spawn N crates en ligne devant l'hélico, espacées de 5 m
    local spawnedCount = 0
    for i = 1, required do
        local dist = 15 + (i - 1) * 5   -- 15 m, 20 m, 25 m ...
        local nx   = pPos.x + math.cos(hdg) * dist
        local nz   = pPos.z + math.sin(hdg) * dist
        local pos  = { x = nx, y = land.getHeight({ x = nx, y = nz }), z = nz }
        local crate = cm:spawnCrate(
            fobDesc, pos, cId, "scenario_fob_scene", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)
        if crate then spawnedCount = spawnedCount + 1 end
    end

    check("F-SCN.2", "3 crates FOB spawned", spawnedCount == required,
        "spawned=" .. spawnedCount .. " required=" .. required)

    -- Centroid FOB : 100 m à 12h devant l'hélico
    local fx  = pPos.x + math.cos(hdg) * 100
    local fz  = pPos.z + math.sin(hdg) * 100
    local centroid = { x = fx, y = land.getHeight({x = fx, y = fz}), z = fz }

    -- Destruction des crates (simule le consume de unpackFOBCrates)
    for _, c in ipairs(cm:getCratesInRange(pPos, 750)) do
        if c.coalition == cId and c.descriptor and c.descriptor.unit == "FOB" then
            cm:destroyCrate(c.crateName)
        end
    end

    -- Lancement direct de la scène (bypass guards pour recette visuelle).
    -- Step 21 (func-only) appelle CTLDFOBManager:_registerDeployedFOB(ctx.scene)
    -- automatiquement — pas besoin de callback onComplete ici.
    local sceneStarted = CTLDSceneManager.getInstance():playScene(
        transport, "FOB",
        {
            player        = playerName,
            centroid      = centroid,
            coalitionId   = cId,
            countryId     = transport:getCountry(),
            transportName = transport:getName(),
            cratesUsed    = {},
        }
    )
    check("F-SCN.3", "scene fobScene demarree", sceneStarted ~= nil)

    report("Crates spawned (" .. spawnedCount .. "). Unpack dans 2 s.")
    report("Observer la scene de construction (120 s).")
    report("Reinjecter ce script a T+130 pour verifier le FOB.")

    _G[STEP_VAR] = 2

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérification FOB enregistré (~T+130)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local transport = ctld_test.getTransport()
    local cId = transport and transport:getCoalition() or coalition.side.BLUE

    local fobMgr = CTLDFOBManager.getInstance()
    local fobs   = fobMgr:getFOBsForCoalition(cId)

    check("F-SCN.3", "au moins 1 FOB enregistre pour BLUE", #fobs >= 1,
        "count=" .. #fobs)

    if #fobs >= 1 then
        local fob = fobs[1]
        check("F-SCN.4", "FOB isAlive()", fob:isAlive())

        local intPct = math.floor(fob:getIntegrityPercent() * 100 + 0.5)
        check("F-SCN.5", "integrity = 100%", intPct == 100, "integrity=" .. intPct .. "%")

        report(string.format("FOB '%s' @ (%.0f, %.0f) — %d%% integrite",
            fob.name, fob.position.x, fob.position.z, intPct))

        if fob.beacon then
            report(string.format("Beacon: VHF %.1f kHz / UHF %.1f MHz / FM %.1f MHz",
                fob.beacon.vhf / 1000,
                fob.beacon.uhf / 1000000,
                fob.beacon.fm  / 1000000))
        end
    end

    pass("Step 2 — verification FOB complete")
    _G[STEP_VAR] = 99

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP FINAL — Résumé
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then
    report("═══════════════════════════════════")
    report("FOB-SCN — ALL STEPS COMPLETE")
    report("═══════════════════════════════════")
    _G[STEP_VAR] = 1

else
    fail("step=" .. step .. " sans branche — reset avec _reset_steps.lua")
end

end)  -- end pcall

-- ── cleanup debug ─────────────────────────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

-- ── return Witchcraft ─────────────────────────────────────────────────────────
if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ step=" .. step .. " SUCCESS", 30, true)
return TAG .. " step=" .. step .. " SUCCESS"
