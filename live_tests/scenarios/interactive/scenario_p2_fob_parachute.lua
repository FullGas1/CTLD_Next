---@diagnostic disable
-- =============================================================================
-- scenarios/interactive/scenario_p2_fob_parachute.lua
-- TODO [P] sous-cas 2 — FOB auto-unpack depuis parachutage
--
-- Valide :
--   (a) checkSpatialGuards bloque si trop proche d'une LGZ existante
--   (b) quand les guards passent : scene joue + FOB enregistré dans CTLDFOBManager
--
-- Steps :
--   Step 1 — Spawn 3 FOB crates LANDED+fromParachute près du transport
--             + register LGZ fictive au centroïde → guard doit bloquer
--             + _checkAutoUnpack => aucune scène lancée (guard fail)
--   Step 2 — Retirer la LGZ fictive → _checkAutoUnpack => scène FOB lance
--   Step 3 (T+130) — Vérifier FOB enregistré
--
-- Prérequis : UH-1H BLUE au sol, > 500 m de toute zone logistique existante
-- =============================================================================

local TAG      = "[P2-FOB-PARA]"
local STEP_VAR = "_P2_FOB_PARA_STEP"
local FAKE_LGZ = "_p2_fake_lgz_"

trigger.action.outText(
    "[P2-FOB-PARA] TODO [P] sous-cas 2 : FOB parachute auto-unpack\n"
    .. "PRE : UH-1H BLUE au sol, > 500 m de toute LGZ\n"
    .. "RUN : step 1 => guard test + spawn crates\n"
    .. "      step 2 => re-injecter tout de suite apres step 1\n"
    .. "      step 3 => re-injecter a T+130",
    30)

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
-- STEP 1 — Guard test : LGZ fictive au centroïde → guard doit bloquer
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    ctld_test.cleanup()

    local transport = ctld_test.getTransport()
    if not transport then fail("aucun joueur BLUE") end

    local cId   = transport:getCoalition()
    local pPos  = transport:getPoint()
    local hdg   = ctld.utils.getHeadingInRadians("p2", transport, true)

    -- Cleanup FOBs existants
    local fobMgr = CTLDFOBManager.getInstance()
    for _, fob in ipairs(fobMgr:getFOBsForCoalition(cId)) do
        pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(fob.name) end)
        fobMgr._fobs[fob.fobId] = nil
    end
    fobMgr._objectToFOB = {}

    -- Descriptor FOB
    local cm      = CTLDCrateManager.getInstance()
    local fobDesc = cm:findDescriptorByUnitType("FOB")
    check("P2.1", "FOB descriptor present", fobDesc ~= nil)
    if not fobDesc then fail("FOB descriptor absent") end

    -- Centroïde : 80 m devant l'hélico
    local cx = pPos.x + math.cos(hdg) * 80
    local cz = pPos.z + math.sin(hdg) * 80
    local cy = land.getHeight({ x = cx, y = cz })
    local centroid = { x = cx, y = cy, z = cz }

    -- Spawn 3 FOB crates LANDED + fromParachute autour du centroïde (< 20 m)
    local spawned = 0
    for i = 1, 3 do
        local angle = (i - 1) * (2 * math.pi / 3)
        local nx = cx + math.cos(angle) * 8
        local nz = cz + math.sin(angle) * 8
        local ny = land.getHeight({ x = nx, y = nz })
        local c = cm:spawnCrate(fobDesc, { x = nx, y = ny, z = nz }, cId,
            "p2_script", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)
        if c then
            c.state         = CTLDCrate.STATE.LANDED
            c.fromParachute = true
            c.position      = { x = nx, y = ny, z = nz }
            spawned = spawned + 1
        end
    end
    check("P2.2", "3 crates FOB spawnees LANDED+fromParachute", spawned == 3,
        "spawned=" .. spawned)

    -- Enregistrer LGZ fictive AU centroïde (guard : trop proche = bloqué)
    local fakeRadius = ctld.gs("fobLogisticZoneRadius") or 150
    CTLDZoneManager.getInstance():registerFOBAsLogistic(FAKE_LGZ, centroid, fakeRadius, cId)
    report("LGZ fictive '" .. FAKE_LGZ .. "' enregistree au centroide")

    -- Compter les FOB avant le test
    local fobsBefore = #fobMgr:getFOBsForCoalition(cId)

    -- _checkAutoUnpack : doit être bloqué par la guard
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor and c.descriptor.unit == "FOB" then
            cm:_checkAutoUnpack(c)
            break
        end
    end

    local fobsAfter = #fobMgr:getFOBsForCoalition(cId)
    check("P2.3", "guard bloque FOB auto-unpack quand LGZ trop proche",
        fobsAfter == fobsBefore,
        "fobsBefore=" .. fobsBefore .. " fobsAfter=" .. fobsAfter)

    report("Step 1 OK. Re-injecter immediatement pour step 2 (retrait LGZ).")
    _G[STEP_VAR] = 2

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Happy path : retirer la LGZ fictive → auto-unpack déclenche la scène
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local transport = ctld_test.getTransport()
    local cId = transport and transport:getCoalition() or coalition.side.BLUE

    -- Retirer la LGZ fictive
    pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(FAKE_LGZ) end)
    report("LGZ fictive '" .. FAKE_LGZ .. "' retiree")

    local fobMgr    = CTLDFOBManager.getInstance()
    local fobsBefore = #fobMgr:getFOBsForCoalition(cId)
    local cm         = CTLDCrateManager.getInstance()

    -- _checkAutoUnpack : guards passent maintenant → scène FOB se lance
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor and c.descriptor.unit == "FOB" then
            cm:_checkAutoUnpack(c)
            break
        end
    end

    -- La scène démarre de façon asynchrone (timers) — on vérifie dans 130 s
    report("Scene FOB lancee (async). Re-injecter a T+130 pour verifier le FOB.")
    _G[STEP_VAR] = 3

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Vérifier FOB enregistré (~T+130)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local transport = ctld_test.getTransport()
    local cId = transport and transport:getCoalition() or coalition.side.BLUE

    local fobMgr = CTLDFOBManager.getInstance()
    local fobs   = fobMgr:getFOBsForCoalition(cId)

    check("P2.4", "au moins 1 FOB enregistre apres auto-unpack parachute",
        #fobs >= 1, "count=" .. #fobs)

    if #fobs >= 1 then
        local fob = fobs[1]
        check("P2.5", "FOB isAlive()", fob:isAlive())
        local intPct = math.floor(fob:getIntegrityPercent() * 100 + 0.5)
        check("P2.6", "integrity = 100%", intPct == 100, "integrity=" .. intPct .. "%")
        report(string.format("FOB '%s' @ (%.0f, %.0f) — %d%% integrite",
            fob.name, fob.position.x, fob.position.z, intPct))
    end

    pass("P2 COMPLETE — FOB parachute auto-unpack valide")
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
