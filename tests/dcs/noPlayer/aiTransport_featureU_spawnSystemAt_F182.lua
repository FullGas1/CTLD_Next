---@diagnostic disable
-- =============================================================================
-- aiTransport_featureU_spawnSystemAt_F182.lua  [AUTO]
-- F-182 — Feature U : spawnSystemAt — positions, limit gate, event
--
-- PRÉREQUIS : CTLD initialisé, CTLDCrateAssemblyManager accessible.
--   Ne nécessite pas de zones DCS dans le .miz.
--
-- OBJECTIF : vérifier que spawnSystemAt() :
--   F-182.1  template inconnu → return false, aucun spawn
--   F-182.2  limite atteinte  → return false, outText coalition
--   F-182.3  HAWK (3 launchers par défaut) → positions et types corrects
--            - #positions = 1 (Hawk ln ×aaLaunchers) + 2 (Hawk tr) + 2 (Hawk sr) +
--              1 (Hawk pcp NoCrate) + 2 (Hawk cwar NoCrate) = non — amount défini dans template
--              HAWK: launcher (amount=aaLaunchers=3), tr (amount=2), sr (amount=2),
--              pcp (NoCrate, amount=1), cwar (NoCrate, amount=2) → total = 3+2+2+1+2 = 10
--   F-182.4  OnAASystemDeployed event publié avec systemName correct
--   F-182.5  spawnedGroup enregistré dans _completeSystems
--
-- NOTE : dynAdd est stubbé en mock pour éviter le spawn DCS réel.
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-182] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_F182_RUNNING then
    trigger.action.outText("[F-182] already running.", 10)
    return Witchcraft
end
_SCN_F182_RUNNING = true

do  -- isolation scope
local TAG   = "[F-182]"
local START = os.date("%Y-%m-%d %H:%M:%S")

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

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

report("==== START " .. START .. " ====")

local aam = CTLDCrateAssemblyManager.getInstance()

-- ── Mocks ─────────────────────────────────────────────────────────────────────

-- Mock dynAdd pour intercepter le spawn sans injecter en DCS
local _orig_dynAdd = ctld.utils.dynAdd
local _lastGroupData = nil
local _dynAddCalled  = false
ctld.utils.dynAdd = function(caller, groupData)
    _lastGroupData  = groupData
    _dynAddCalled   = true
    -- Simuler un résultat Group avec name
    return { name = groupData.name }
end

-- Mock Group.getByName pour retourner un stub
local _orig_GBN = Group.getByName
local _stubGroup = {
    getName    = function() return "STUB_HAWK_GROUP" end,
    getUnits   = function() return {} end,
    getCoalition = function() return coalition.side.BLUE end,
}
Group.getByName = function(name)
    if name and name:find("CTLD_AA_") then return _stubGroup end
    return _orig_GBN(name)
end

-- Mock EventDispatcher pour capturer l'event
local _eventPublished = nil
local _origED_publish = EventDispatcher.getInstance().publish
EventDispatcher.getInstance().publish = function(self, evtName, data)
    _eventPublished = { name = evtName, data = data }
end

-- ── F-182.1 : template inconnu → false ───────────────────────────────────────
local r1 = aam:spawnSystemAt("Unknown System", {x=0,y=0,z=0}, coalition.side.BLUE, 2)
check("F-182.1", "spawnSystemAt inconnu → false", r1 == false)

-- ── F-182.2 : limite atteinte → false ────────────────────────────────────────
local _orig_countComplete = aam.countComplete
local _orig_getAllowed     = aam.getAllowedCount
aam.countComplete    = function() return 20 end
aam.getAllowedCount   = function() return 20 end

local r2 = aam:spawnSystemAt("HAWK AA System", {x=0,y=0,z=0}, coalition.side.BLUE, 2)
check("F-182.2", "spawnSystemAt limite atteinte → false", r2 == false)

aam.countComplete  = _orig_countComplete
aam.getAllowedCount = _orig_getAllowed

-- ── F-182.3 : HAWK — positions générées ─────────────────────────────────────
_dynAddCalled  = false
_lastGroupData = nil
_eventPublished = nil

-- Forcer aaLaunchers=3 (défaut)
local cfg_saved_aa = cfg.settings["aaLaunchers"]
cfg.settings["aaLaunchers"] = 3

local testPt = { x = 100, y = 10, z = 200 }
local r3 = aam:spawnSystemAt("HAWK AA System", testPt, coalition.side.BLUE, 2)
check("F-182.3", "spawnSystemAt HAWK → true", r3 == true)
check("F-182.3b", "dynAdd appelé", _dynAddCalled)

-- HAWK parts: launcher (×aaLaunchers=3), tr (×2), sr (×2), pcp (NoCrate ×1), cwar (NoCrate ×2)
-- total units = 3 + 2 + 2 + 1 + 2 = 10
if _lastGroupData then
    local nUnits = #_lastGroupData.units
    check("F-182.3c", "10 unités générées (3+2+2+1+2)",
          nUnits == 10, "nUnits=" .. tostring(nUnits))
    -- Vérifier que le premier type est "Hawk ln" (launcher en premier dans TEMPLATES)
    local firstType = _lastGroupData.units[1] and _lastGroupData.units[1].type
    check("F-182.3d", "1ère unité type='Hawk ln'",
          firstType == "Hawk ln", tostring(firstType))
    -- Vérifier que tous les x/z sont différents de l'origine (cercle décalé)
    local allOffset = true
    for _, u in ipairs(_lastGroupData.units) do
        if u.x == testPt.x and u.y == testPt.z then allOffset = false end
    end
    check("F-182.3e", "toutes les positions décalées de l'origine (cercle)", allOffset)
end

cfg.settings["aaLaunchers"] = cfg_saved_aa

-- ── F-182.4 : event OnAASystemDeployed publié ────────────────────────────────
check("F-182.4", "OnAASystemDeployed publié",
      _eventPublished ~= nil and _eventPublished.name == "OnAASystemDeployed",
      tostring(_eventPublished and _eventPublished.name))
if _eventPublished and _eventPublished.data then
    check("F-182.4b", "event.systemName='HAWK AA System'",
          _eventPublished.data.systemName == "HAWK AA System",
          tostring(_eventPublished.data.systemName))
    check("F-182.4c", "event.coalition=BLUE",
          _eventPublished.data.coalition == coalition.side.BLUE,
          tostring(_eventPublished.data.coalition))
end

-- ── F-182.5 : _completeSystems peuplé ────────────────────────────────────────
local found = false
for grpName, entry in pairs(aam._completeSystems) do
    if entry.template and entry.template.name == "HAWK AA System" then
        found = true
    end
end
check("F-182.5", "_completeSystems contient l'entrée HAWK", found)

-- ── Restauration mocks ────────────────────────────────────────────────────────
ctld.utils.dynAdd = _orig_dynAdd
Group.getByName   = _orig_GBN
EventDispatcher.getInstance().publish = _origED_publish
-- Nettoyer _completeSystems du stub
for grpName, entry in pairs(aam._completeSystems) do
    if entry.template and entry.template.name == "HAWK AA System" then
        aam._completeSystems[grpName] = nil
    end
end

_result = "ALL SUCCESS"
end)

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    ctld.utils.dynAdd = ctld.utils.dynAdd  -- no-op restore guard
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F182_RUNNING = false
    return TAG .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ ALL PASS (" .. _ms .. "ms)", 30, true)
_SCN_F182_RUNNING = false
return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end  -- do isolation scope
return Witchcraft
