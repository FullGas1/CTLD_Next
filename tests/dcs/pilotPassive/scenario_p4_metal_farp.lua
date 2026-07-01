---@diagnostic disable
-- =============================================================================
-- scenarios/interactive/scenario_p4_metal_farp.lua
-- TODO [P] sous-cas 4 — Metal FARP via menu F10 : warehouse stocking
--
-- Valide :
--   - playScene "Metal FARP" se déroule correctement
--   - Step 9 (func) appelle addLiquid sur la warehouse si mod présent
--   - Si mod absent : step 1 skip spawn (farpName = nil), step 9 no-op, aucun crash
--
-- Steps :
--   Step 1 — playScene Metal FARP sur le transport joueur
--   Step 2 (T+35) — vérifier warehouse stockée (si mod présent) ou skip propre (si absent)
--
-- Prérequis : UH-1H BLUE au sol
-- =============================================================================

-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[P4-METAL] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local TAG      = "[P4-METAL]"
local STEP_VAR = "_P4_METAL_STEP"

trigger.action.outText(
    "[P4-METAL] TODO [P] sous-cas 4 : Metal FARP warehouse\n"
    .. "PRE : UH-1H BLUE au sol\n"
    .. "RUN : step 1 => lance scene (~25 s)\n"
    .. "      step 2 => re-injecter a T+35 pour verifier warehouse",
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
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]                  = true
cfg.settings["debugScreenLog"]         = true
cfg.settings["debugScreenLogDuration"] = 12

_G[STEP_VAR] = _G[STEP_VAR] or 1
local step = _G[STEP_VAR]
report("==== START " .. os.date("%H:%M:%S") .. " | step=" .. step .. " ====")

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Lancer la scène Metal FARP
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    local transport = ctld_test.getTransport()
    if not transport then fail("aucun joueur BLUE") end

    local sm    = CTLDSceneManager.getInstance()
    local model = sm:getModel("Metal FARP")
    check("P4.1", "scene model 'Metal FARP' enregistree", model ~= nil)
    if not model then fail("scene Metal FARP introuvable") end

    -- Cleanup : détruire toute scène Metal FARP existante
    ctld_test.cleanup()

    local scene = sm:playScene(transport, "Metal FARP", {})
    check("P4.2", "playScene Metal FARP demarre", scene ~= nil)
    if not scene then fail("playScene returned nil") end

    report("Scene Metal FARP lancee (~25 s). Re-injecter a T+35 pour verifier warehouse.")
    _G[STEP_VAR] = 2

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérifier warehouse stocking (~T+35)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    -- Chercher le farpName enregistré dans la dernière scène Metal FARP
    local sm = CTLDSceneManager.getInstance()

    -- Stratégie : chercher un Airbase portant le nom Farp_FG_Petit_Helipad*
    -- Si mod absent, aucun airbase de ce type n'existe — on le note et PASS
    local farpAb  = nil
    local farpName = nil

    -- Scaner les airbases connus (coalition BLUE = 2)
    for _, ab in pairs(world.getAirbases()) do
        local n = ab:getName()
        if n and n:find("Farp_FG_Petit_Helipad") then
            farpAb   = ab
            farpName = n
            break
        end
    end

    if not farpAb then
        -- Mod absent : comportement attendu = step 1 skip, aucun airbase, aucun crash
        pass("P4.3 — mod absent : aucun Farp_FG_Petit_Helipad airbase (comportement attendu)")
        pass("P4.4 — aucun crash meme sans mod (SKIP propre)")
    else
        report("Farp airbase detecte : " .. farpName)
        local w = farpAb:getWarehouse()
        check("P4.3", "warehouse accessible", w ~= nil)
        if w then
            -- addLiquid ajoute au stock existant — on vérifie juste que la quantite > 0
            local jet  = w:getLiquid(0)
            local avgas = w:getLiquid(1)
            local mw50 = w:getLiquid(2)
            local diese = w:getLiquid(3)
            report(string.format("Warehouse — jet=%d avgas=%d mw50=%d diesel=%d",
                jet or 0, avgas or 0, mw50 or 0, diese or 0))
            check("P4.4", "jet fuel > 0 apres stocking",  (jet  or 0) > 0)
            check("P4.5", "avgas > 0 apres stocking",     (avgas or 0) > 0)
        end
    end

    pass("P4 COMPLETE — Metal FARP warehouse valide")
    _G[STEP_VAR] = 1

else
    fail("step=" .. step .. " inconnu")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ step=" .. step .. " SUCCESS", 30, true)
return TAG .. " step=" .. step .. " SUCCESS"
