---@diagnostic disable
-- =============================================================================
-- aiTransport_featureU_F181.lua  [AUTO]
-- F-181 — Feature U : getTemplateByName + aiPickVehicleEntry isAASystem
--
-- PRÉREQUIS : CTLD initialisé, CTLDCrateAssemblyManager et CTLDSceneManager accessibles.
--   Ne nécessite pas de zones DCS dans le .miz.
--
-- OBJECTIF : vérifier que :
--   F-181.1  getTemplateByName("HAWK AA System")   → template non-nil
--   F-181.2  getTemplateByName("Patriot AA System") → template non-nil
--   F-181.3  getTemplateByName("NASAMS AA System")  → template non-nil
--   F-181.4  getTemplateByName("BUK AA System")     → template non-nil
--   F-181.5  getTemplateByName("KUB AA System")     → template non-nil
--   F-181.6  getTemplateByName("S-300 AA System")   → template non-nil
--   F-181.7  getTemplateByName("Unknown System")    → nil
--   F-181.8  aiPickVehicleEntry sur stock { ["HAWK AA System"]=1 } → isAASystem=true, isScene=false
--   F-181.9  aiPickVehicleEntry sur stock { ["FARP Alpha"]=1 }     → isScene=true,    isAASystem=false/nil
--   F-181.10 aiPickVehicleEntry sur stock { ["Hummer"]=1 }         → isScene=false,   isAASystem=false/nil
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-181] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_F181_RUNNING then
    trigger.action.outText("[F-181] already running.", 10)
    return Witchcraft
end
_SCN_F181_RUNNING = true

do  -- isolation scope
local TAG   = "[F-181]"
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

-- ── F-181.1 à F-181.6 : getTemplateByName — tous les templates connus ───────
local knownTemplates = {
    "HAWK AA System",
    "Patriot AA System",
    "NASAMS AA System",
    "BUK AA System",
    "KUB AA System",
    "S-300 AA System",
}
for i, name in ipairs(knownTemplates) do
    local t = aam:getTemplateByName(name)
    check("F-181." .. i, "getTemplateByName('" .. name .. "') → non-nil", t ~= nil)
    if t then
        check("F-181." .. i .. "b", "template.name == '" .. name .. "'",
              t.name == name, tostring(t.name))
        check("F-181." .. i .. "c", "template.parts non-vide",
              type(t.parts) == "table" and #t.parts > 0,
              "parts count=" .. tostring(t.parts and #t.parts))
    end
end

-- ── F-181.7 : nom inconnu → nil ─────────────────────────────────────────────
check("F-181.7", "getTemplateByName('Unknown System') → nil",
      aam:getTemplateByName("Unknown System") == nil)
check("F-181.7b", "getTemplateByName(nil) → nil (guard)",
      aam:getTemplateByName(nil) == nil)

-- ── F-181.8 : aiPickVehicleEntry HAWK AA System → isAASystem=true ───────────
-- Fake zones : tables brutes avec les champs requis ; on appelle la méthode en dot notation
local function makeFakeZone(stockTable)
    return { _aiVehicleStock = { isAll=false, init=stockTable, current=stockTable } }
end

local fakeZoneHawk = makeFakeZone({ ["HAWK AA System"] = 1 })
local entryHawk = CTLDTroopZone.aiPickVehicleEntry(fakeZoneHawk)
check("F-181.8", "entry HAWK non-nil", entryHawk ~= nil)
if entryHawk then
    check("F-181.8b", "entry.type='HAWK AA System'",
          entryHawk.type == "HAWK AA System", tostring(entryHawk.type))
    check("F-181.8c", "entry.isAASystem=true",
          entryHawk.isAASystem == true, tostring(entryHawk.isAASystem))
    check("F-181.8d", "entry.isScene=false",
          entryHawk.isScene == false, tostring(entryHawk.isScene))
end

-- ── F-181.9 : FARP Alpha → isScene=true ─────────────────────────────────────
local fakeZoneFarp = makeFakeZone({ ["FARP Alpha"] = 1 })
local entryFarp = CTLDTroopZone.aiPickVehicleEntry(fakeZoneFarp)
check("F-181.9", "entry FARP Alpha non-nil", entryFarp ~= nil)
if entryFarp then
    check("F-181.9b", "entry.isScene=true (CTLDSceneManager)",
          entryFarp.isScene == true, tostring(entryFarp.isScene))
    check("F-181.9c", "entry.isAASystem=false (scène passe avant AA)",
          entryFarp.isAASystem == false or entryFarp.isAASystem == nil,
          tostring(entryFarp.isAASystem))
end

-- ── F-181.10 : Hummer → DCS natif (isScene=false, isAASystem=false) ──────────
local fakeZoneHummer = makeFakeZone({ ["Hummer"] = 1 })
local entryHummer = CTLDTroopZone.aiPickVehicleEntry(fakeZoneHummer)
check("F-181.10", "entry Hummer non-nil", entryHummer ~= nil)
if entryHummer then
    check("F-181.10b", "entry.isScene=false (DCS natif)",
          entryHummer.isScene == false, tostring(entryHummer.isScene))
    check("F-181.10c", "entry.isAASystem=false (DCS natif, pas de template AA)",
          entryHummer.isAASystem == false or entryHummer.isAASystem == nil,
          tostring(entryHummer.isAASystem))
end

_result = "ALL SUCCESS"
end)

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F181_RUNNING = false
    return TAG .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ ALL PASS (" .. _ms .. "ms)", 30, true)
_SCN_F181_RUNNING = false
return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end  -- do isolation scope
return Witchcraft
