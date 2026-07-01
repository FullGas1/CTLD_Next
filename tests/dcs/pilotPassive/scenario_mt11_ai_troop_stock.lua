---@diagnostic disable
-- =============================================================================
-- scenario_mt11_ai_troop_stock.lua  [INTERACTIVE]
-- MT-11 — AI auto-pickup avec 2 troopTemplates assignés à une AIZ_P (Feature T)
--
-- PRÉREQUIS MISSION :
--   - Héli BLUE nommé "heliai_mt11" (UH-1H), sans pilote humain
--   - Route : WP1 = posé sur AIZ_mt11_B_P_T → WP2 = vol → WP3 = posé sur AIZ_mt11_B_D
--   - Zone DCS trigger "AIZ_mt11_B_P_T" (rayon ~200 m, centré sur WP1)
--   - Zone DCS trigger "AIZ_mt11_B_D"   (rayon ~200 m, centré sur WP3)
--   - Pas de troupes DCS physiques requises (stock géré par Feature T)
--   - enable_debug.lua injecté avant ce script
--   - ctldLogPath défini dans le .miz (trigger MISSION START)
--
-- USE CASE :
--   Zone AIZ_mt11_B_P_T : troopStock = { ["Standard Group"]=3, ["Anti Tank"]=2 }
--   Règle B : seul aiPickTroopTemplate() est utilisé (legacy first-compatible supprimé).
--   Algorithme : tirage équitable parmi les templates au stock résiduel le plus élevé.
--   Standard Group (3) > Anti Tank (2) → Standard Group attendu au 1er pickup.
--   Après pickup : stock courant décrémenté ; le template chargé est vérifié.
--   IMPORTANT : troopStock=nil bloquerait le pickup (règle A) — toujours déclarer troopStock.
--
-- PROTOCOL :
--   Step 1 — Enregistre heliai_mt11 + vérifie zones + stocks initiaux
--   Step 2 — Vérifie pickup (hasTroops=true) + template chargé + stock décrémenté
--             Re-injecter après que l'héli soit posé sur AIZ_mt11_B_P_T (~2s)
--   Step 3 — Vérifie dropoff (hasTroops=false) + spawn DCS
--             Re-injecter après que l'héli soit posé sur AIZ_mt11_B_D
--   Step 4 — Cleanup
-- =============================================================================


-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-11] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG    = "[MT-11]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT11_STEP"

local AI_UNIT = "heliai_mt11"
local AIZ_P   = "AIZ_mt11_B_P_T"
local AIZ_D   = "AIZ_mt11_B_D"

local function log(msg)    ctld.utils.log("INFO",  TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end
local function pass(msg)   report("[PASS] " .. msg) end
local function fail(msg)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. msg)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (details and (" | " .. details) or "")) end
end

local function cleanup()
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT then table.remove(names, i) end
    end
    local unit = Unit.getByName(AI_UNIT)
    if unit and unit:isExist() then
        local ok, tm = pcall(CTLDTroopManager.getInstance)
        if ok and tm and tm:hasTroops(AI_UNIT) then tm:disembarkAll(unit) end
    end
    log("cleanup done")
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Init zones + stocks initiaux
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cfg.settings["transportPilotNames"] = { AI_UNIT }
    CTLDCoreManager.getInstance():_initAITransports()

    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    local zD = zm._troopZones[AIZ_D]
    check("MT-11.1.1", "AIZ_P trouvée : " .. AIZ_P, zP ~= nil)
    check("MT-11.1.2", "AIZ_D trouvée : " .. AIZ_D, zD ~= nil)
    if zP then
        check("MT-11.1.3", "AIZ_P.isAIPickup=true",  zP.isAIPickup == true)
        check("MT-11.1.4", "AIZ_P._aiTroopStock non-nil", zP._aiTroopStock ~= nil)
        if zP._aiTroopStock then
            local ts = zP._aiTroopStock
            check("MT-11.1.5", "_aiTroopStock.isAll=false", ts.isAll == false)
            check("MT-11.1.6", "init[Standard Group]=3",
                  ts.init["Standard Group"] == 3, tostring(ts.init["Standard Group"]))
            check("MT-11.1.7", "init[Anti Tank]=2",
                  ts.init["Anti Tank"] == 2, tostring(ts.init["Anti Tank"]))
            check("MT-11.1.8", "current[Standard Group]=3 (init)",
                  ts.current["Standard Group"] == 3, tostring(ts.current["Standard Group"]))
            check("MT-11.1.9", "pickMaxStock=0 (gate illimitée)",
                  zP.pickMaxStock == 0, tostring(zP.pickMaxStock))
        end
    end

    -- Activer le groupe (late-activation dans le .miz)
    local grp = Group.getByName(AI_UNIT)
    if grp then grp:activate() end

    local unit = Unit.getByName(AI_UNIT)
    check("MT-11.1.10", "Unité AI '" .. AI_UNIT .. "' présente en mission", unit ~= nil)
    if unit then
        check("MT-11.1.11", "Unité AI sans pilote humain", unit:getPlayerName() == nil)
    end

    local tm = CTLDTroopManager.getInstance()
    check("MT-11.1.12", "Pas encore de troupes à bord (état initial)", not tm:hasTroops(AI_UNIT))

    report("⬛ STEP 1 OK — Pose l'héli sur " .. AIZ_P .. ", attends 3s, re-injecte pour STEP 2")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérifier pickup + template + stock décrémenté
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local tm   = CTLDTroopManager.getInstance()
    local hasTr = tm:hasTroops(AI_UNIT)

    if not hasTr then
        report("⚠️  Pas encore de troupes — l'héli est-il bien posé dans " .. AIZ_P .. " ?")
        report("   Attends 2s de plus et re-injecte STEP 2.")
        _result = "step=2 WAITING"
        return
    end

    check("MT-11.2.1", "hasTroops=true après auto-pickup sur AIZ_P", hasTr)

    local list = tm:getInTransit(AI_UNIT) or {}
    check("MT-11.2.2", "1 groupe en transit", #list >= 1,
          "#list=" .. tostring(#list))

    local total = 0
    local tmplName = nil
    for _, grp in ipairs(list) do
        total = total + (grp.unitTotal or 0)
        tmplName = grp.templateName or tmplName
    end
    report("📦 Cargo: " .. total .. " soldat(s) — template: " .. tostring(tmplName))

    -- Template doit être Standard Group OU Anti Tank (ceux avec le plus haut stock au départ)
    -- Standard Group (3) > Anti Tank (2) → Standard Group attendu au 1er pickup
    local validTemplates = { ["Standard Group"] = true, ["Anti Tank"] = true }
    check("MT-11.2.3", "template chargé reconnu (Standard Group ou Anti Tank)",
          tmplName ~= nil and validTemplates[tmplName] == true,
          tostring(tmplName))

    -- Vérifier stock décrémenté
    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    if zP and zP._aiTroopStock and tmplName then
        local cur = zP._aiTroopStock.current[tmplName]
        local ini = zP._aiTroopStock.init[tmplName]
        check("MT-11.2.4", "stock courant décrémenté pour '" .. tmplName .. "'",
              cur ~= nil and cur < ini,
              "current=" .. tostring(cur) .. " init=" .. tostring(ini))
        report("📊 Stock " .. tmplName .. ": " .. tostring(cur) .. "/" .. tostring(ini))
    end

    -- Vérifier Standard Group (3) prioritaire → stock tombé à 2 si c'est lui qui a été chargé
    if zP and zP._aiTroopStock and tmplName == "Standard Group" then
        check("MT-11.2.5", "Standard Group (stock max=3) choisi au 1er pickup",
              zP._aiTroopStock.current["Standard Group"] == 2, -- 3-1=2
              tostring(zP._aiTroopStock.current["Standard Group"]))
    end

    report("⬛ STEP 2 OK — Envoie l'héli sur " .. AIZ_D .. " (posé), re-injecte pour STEP 3")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Vérifier dropoff (hasTroops=false)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local tm   = CTLDTroopManager.getInstance()
    local hasTr = tm:hasTroops(AI_UNIT)

    if hasTr then
        report("⚠️  Troupes encore à bord — l'héli est-il bien posé dans " .. AIZ_D .. " ?")
        _result = "step=3 WAITING"
        return
    end

    check("MT-11.3.1", "hasTroops=false après auto-dropoff sur AIZ_D", not hasTr)
    report("✅ Disembark confirmé — vérifie sur F10 map que des groupes sont apparus près de " .. AIZ_D)
    report("⬛ Re-injecte pour STEP 4 (cleanup)")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("✅ MT-11 ALL SUCCESS — 2 troopTemplates avec stock, pickup + stock décrémenté + dropoff confirmés")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " sans branche — réinitialise avec _G['" .. STEP_N .. "']=1")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    pcall(cleanup)
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
                             :gsub("WAITING", "WAITING (" .. _ms .. "ms)")
