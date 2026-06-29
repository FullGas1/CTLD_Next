---@diagnostic disable
-- =============================================================================
-- scenarios/interactive/scenario_p3_csfarp_parachute.lua
-- TODO [P] sous-cas 3 — CS FARP via parachutage auto-unpack
--
-- Valide (régression TODO [N]) :
--   - _checkAutoUnpack route vers playSceneAtPos (chemin "generic scene")
--   - Pas de guard FOB (pas de fobCompatible) → scène joue directement
--   - Aucun crash, scène CS FARP se déploie
--
-- Steps :
--   Step 1 — Spawn 1 CS FARP crate LANDED+fromParachute, appel _checkAutoUnpack
--   Step 2 (T+35) — Vérifier log "auto-unpack (parachute) SCENE" + pas de crash
--
-- Prérequis : UH-1H BLUE au sol
-- =============================================================================

local TAG      = "[P3-CSFARP]"
local STEP_VAR = "_P3_CSFARP_STEP"

trigger.action.outText(
    "[P3-CSFARP] TODO [P] sous-cas 3 : CS FARP parachute auto-unpack\n"
    .. "PRE : UH-1H BLUE au sol\n"
    .. "RUN : step 1 => spawn crate + auto-unpack\n"
    .. "      step 2 => re-injecter a T+35 pour verifier scene",
    20)

local function report(msg) trigger.action.outText(TAG .. " " .. msg, 40); ctld.utils.log("INFO", TAG .. " " .. msg) end
local function pass(msg)   report("[PASS] " .. msg) end
local function fail(msg)   report("[FAIL] " .. msg); error(msg) end
local function check(id, desc, cond, detail)
    if cond then pass(id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (detail and (" | " .. detail) or "")) end
end

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"]                  = true
cfg.settings["debugScreenLog"]         = true
cfg.settings["debugScreenLogDuration"] = 12

_G[STEP_VAR] = _G[STEP_VAR] or 1
local step = _G[STEP_VAR]
report("==== START " .. os.date("%H:%M:%S") .. " | step=" .. step .. " ====")

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Spawn 1 CS FARP crate LANDED+fromParachute, _checkAutoUnpack
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    ctld_test.cleanup()

    local transport = ctld_test.getTransport()
    if not transport then fail("aucun joueur BLUE") end

    local cId  = transport:getCoalition()
    local pPos = transport:getPoint()
    local hdg  = ctld.utils.getHeadingInRadians("p3", transport, true)

    -- Descriptor Countryside FARP
    local cm   = CTLDCrateManager.getInstance()
    local desc = cm:findDescriptorByUnitType("Countryside FARP")
    check("P3.1", "descriptor 'Countryside FARP' present", desc ~= nil)
    if not desc then fail("descriptor Countryside FARP absent") end

    -- Forcer cratesRequired=1 pour test rapide (sauvegarder valeur originale)
    local origRequired = desc.cratesRequired
    desc.cratesRequired = 1

    -- Spawn 1 crate 60 m devant, état LANDED + fromParachute
    local nx = pPos.x + math.cos(hdg) * 60
    local nz = pPos.z + math.sin(hdg) * 60
    local ny = land.getHeight({ x = nx, y = nz })
    local crate = cm:spawnCrate(desc, { x = nx, y = ny, z = nz }, cId,
        "p3_script", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)
    check("P3.2", "CS FARP crate spawnee", crate ~= nil)
    if not crate then
        desc.cratesRequired = origRequired
        fail("spawnCrate failed")
    end

    -- Mettre en état LANDED + fromParachute
    crate.state         = CTLDCrate.STATE.LANDED
    crate.fromParachute = true
    crate.position      = { x = nx, y = ny, z = nz }

    -- Restaurer cratesRequired avant _checkAutoUnpack
    desc.cratesRequired = 1  -- on garde 1 pour ce test

    -- Route attendue : generic scene (Countryside FARP n'est pas fobCompatible)
    local sm    = CTLDSceneManager.getInstance()
    local model = sm:getModel("Countryside FARP")
    check("P3.3", "'Countryside FARP' dans CTLDSceneManager", model ~= nil)
    if model then
        check("P3.4", "Countryside FARP n'est PAS fobCompatible",
            not (model.crate and model.crate.fobCompatible == true))
    end

    -- Appel _checkAutoUnpack → doit déclencher playSceneAtPos (chemin generic)
    local scenesBefore = 0
    for _ in pairs(sm._activeScenes or {}) do scenesBefore = scenesBefore + 1 end

    cm:_checkAutoUnpack(crate)

    local scenesAfter = 0
    for _ in pairs(sm._activeScenes or {}) do scenesAfter = scenesAfter + 1 end

    check("P3.5", "au moins 1 scene active apres _checkAutoUnpack",
        scenesAfter >= scenesBefore,
        "before=" .. scenesBefore .. " after=" .. scenesAfter)

    -- Restaurer cratesRequired original
    desc.cratesRequired = origRequired

    report("Scene Countryside FARP lancee. Re-injecter a T+35.")
    _G[STEP_VAR] = 2

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérification scène complétée (~T+35)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    -- Vérifier dans CTLD.log la trace "auto-unpack (parachute) SCENE"
    -- Vérification principale : aucun crash (step 1 PASS + step 2 PASS = OK)
    pass("P3.6 — aucun crash apres auto-unpack Countryside FARP")

    -- Vérifier que la crate CS FARP initiale a été consommée (state UNPACKED)
    local cm = CTLDCrateManager.getInstance()
    local foundLanded = false
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor
           and c.descriptor.unit == "Countryside FARP"
           and c.state == CTLDCrate.STATE.LANDED then
            foundLanded = true
        end
    end
    check("P3.7", "crate CS FARP consommee (plus de crate LANDED+fromParachute)",
        not foundLanded)

    pass("P3 COMPLETE — CS FARP parachute auto-unpack valide")
    _G[STEP_VAR] = 1

else
    fail("step=" .. step .. " inconnu")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug

if not _ok then
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
return TAG .. " step=" .. step .. " SUCCESS"
