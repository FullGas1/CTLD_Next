---@diagnostic disable
-- =============================================================================
-- aiTransport_featureT_troopRotation_F177.lua  [AUTO]
-- F-177 — Feature T : algorithme de rotation des troopTemplates
--
-- PRÉREQUIS : CTLD initialisé (classes disponibles en mémoire).
--   Ne nécessite pas de zones DCS dans le .miz.
--
-- OBJECTIF : vérifier que aiPickTroopTemplate() sélectionne le template
--   dont le stock courant est le plus élevé (algorithme C), au hasard
--   parmi les ex-aequo. Les templates au stock inférieur ne doivent jamais
--   être choisis.
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-177] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F177_RUNNING then
    trigger.action.outText("[F-177] already running.", 10)
    return Witchcraft
end
_SCN_F177_RUNNING = true

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-177]"
local START = os.date("%Y-%m-%d %H:%M:%S")
ctld_test = ctld_test or {}

local function log(msg)    ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 20); log(msg) end
local function pass(id, desc)   report("[PASS] " .. id .. " — " .. desc) end
local function fail(id, desc, details)
    local msg = "[FAIL] " .. id .. " — " .. desc .. (details and (" | " .. details) or "")
    trigger.action.outText(TAG .. " !! " .. msg, 60); log(msg)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id, desc) else fail(id, desc, details) end
end

report("==== START " .. START .. " ====")

local _ok, _err = pcall(function()

    -- ── Mock transport manager ─────────────────────────────────────────────
    local mockTm = {
        _weightForGroup = function(self, tmpl) return 0 end,
        _canEmbark      = function(self, typeName, unitName, total, w) return true end,
    }

    -- ── Mock teams list ───────────────────────────────────────────────────
    -- Three templates: A (stock=5), B (stock=3), C (stock=5)
    -- Rotation rule: pick randomly among those with MAX stock → always A or C, never B.
    local teamA = { name = "Alpha Squad", total = 4 }
    local teamB = { name = "Bravo Squad", total = 4 }
    local teamC = { name = "Charlie Squad", total = 4 }
    local teams = { teamA, teamB, teamC }

    -- ── Build zone directly with inline stock table ───────────────────────
    local zone = CTLDTroopZone:new({
        zoneName    = "TEST_ROTATION",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = false,
            init    = { ["Alpha Squad"] = 5, ["Bravo Squad"] = 3, ["Charlie Squad"] = 5 },
            current = { ["Alpha Squad"] = 5, ["Bravo Squad"] = 3, ["Charlie Squad"] = 5 },
        },
    })

    -- ── F-177.1 : run 20 picks — B doit ne jamais être choisi ─────────────
    local pickedB = false
    local countA, countC = 0, 0
    for i = 1, 20 do
        local tmpl = zone:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
        if tmpl == nil then
            fail("F-177.1", "aiPickTroopTemplate retourne nil inattendu (iter " .. i .. ")")
        end
        if tmpl.name == "Bravo Squad" then pickedB = true end
        if tmpl.name == "Alpha Squad" then countA = countA + 1 end
        if tmpl.name == "Charlie Squad" then countC = countC + 1 end
    end
    check("F-177.1", "Bravo Squad (stock=3) jamais choisi parmi 20 picks", not pickedB,
          "Bravo Squad picked at least once")
    check("F-177.2", "Alpha Squad ou Charlie Squad (stock=5) toujours choisi",
          countA + countC == 20, "countA=" .. countA .. " countC=" .. countC)

    -- ── F-177.3 : avec stock=0 sur Alpha, seul Charlie eligible ──────────
    zone._aiTroopStock.current["Alpha Squad"] = 0
    local found_alpha = false
    for i = 1, 10 do
        local tmpl = zone:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
        if tmpl and tmpl.name == "Alpha Squad" then found_alpha = true end
    end
    check("F-177.3", "Alpha Squad exclu (stock=0) — seul Charlie eligible", not found_alpha)

    -- ── F-177.4 : all stock=0 → retourne nil ──────────────────────────────
    zone._aiTroopStock.current["Alpha Squad"]   = 0
    zone._aiTroopStock.current["Bravo Squad"]   = 0
    zone._aiTroopStock.current["Charlie Squad"] = 0
    local nilResult = zone:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
    check("F-177.4", "Tous stock=0 → aiPickTroopTemplate retourne nil", nilResult == nil,
          tostring(nilResult and nilResult.name))

    -- ── F-177.5 : isAll=true → toujours retourner un template ────────────
    local zoneAll = CTLDTroopZone:new({
        zoneName    = "TEST_ROTATION_ALL",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = true,
            init    = {},
            current = {},
        },
    })
    local tmplAll = zoneAll:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
    check("F-177.5", "isAll=true → un template est retourné (non-nil)", tmplAll ~= nil,
          "returned nil")

    -- ── F-177.6 : _aiTroopStock=nil → retourne nil (legacy path) ─────────
    local zoneNoStock = CTLDTroopZone:new({
        zoneName    = "TEST_NOSTOCK",
        isAIPickup  = true,
        pickMaxStock = 0,
    })
    local nilLegacy = zoneNoStock:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
    check("F-177.6", "_aiTroopStock=nil → retourne nil (fallback legacy)", nilLegacy == nil)

    report("✅ F-177 ALL PASS — rotation troopTemplates correcte")

end)

if not _ok then
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F177_RUNNING = false
    return TAG .. " FAIL: " .. tostring(_err)
end

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F177_RUNNING = false

end  -- do isolation scope
return Witchcraft
