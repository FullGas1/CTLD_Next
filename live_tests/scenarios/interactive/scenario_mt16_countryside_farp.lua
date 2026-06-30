---@diagnostic disable
-- scenario_mt15_countryside_farp.lua
-- Test interactif : vérifie que la scène Countryside FARP se déploie correctement
-- après migration dans src/scenes/CTLD_countrysideFarpScene.lua.
--
-- Prérequis : joueur BLUE au sol dans un UH-1H, 1 crate "Countryside FARP" à portée
-- Protocole  : injecter ce script → vérifier messages écran + formation scène ~30 s

-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCENARIO_CS_FARP] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local TAG  = "[SCENARIO_CS_FARP]"
local step = 0

local function info(msg)
    trigger.action.outText(TAG .. " " .. msg, 12)
    env.info(TAG .. " " .. msg)
end

-- Nettoyage CTLD
ctld_test.cleanup()

local transport = ctld_test.getTransport()
if not transport then
    info("FAIL — no BLUE transport found")
    return TAG .. " FAIL no transport"
end

-- Vérification 1 : la scène est bien enregistrée dans CTLDSceneManager
local sm = CTLDSceneManager.getInstance()
local model = sm:getModel("Countryside FARP")
if model then
    step = step + 1
    info("CHECK 1 PASS — scene 'Countryside FARP' registered in CTLDSceneManager")
else
    info("CHECK 1 FAIL — scene 'Countryside FARP' NOT registered")
    return TAG .. " FAIL scene not registered"
end

-- Vérification 2 : spawn d'une crate Countryside FARP à portée du transport
local mgr   = CTLDCrateManager.getInstance()
local pt    = transport:getPoint()
local cDesc = mgr:findDescriptorByUnitType("Countryside FARP")
if not cDesc then
    info("CHECK 2 FAIL — no spawnableCrates descriptor for 'Countryside FARP'")
    return TAG .. " FAIL no crate descriptor"
end

-- spawnCrateAtPoint(side, weight, point, hdg) — use correct signature
local side  = transport:getCoalition() == coalition.side.BLUE and "blue" or "red"
local crate = mgr:spawnCrateAtPoint(
    side, cDesc.weight,
    { x = pt.x + 10, y = pt.y, z = pt.z + 10 },
    0
)
if crate then
    step = step + 1
    info("CHECK 2 PASS — crate 'Countryside FARP' spawned near transport")
else
    info("CHECK 2 FAIL — crate spawn returned nil")
    return TAG .. " FAIL crate spawn"
end

-- Vérification 3 : la scène self-registered n'est pas dupliquée (1 seul modèle)
local count = 0
for _ in pairs(sm._models) do count = count + 1 end
info("CTLDSceneManager has " .. count .. " registered models — check no duplicates")

info("Setup done (" .. step .. "/2 checks). Land near crate and use F10 > Unpack Crates > Deploy Countryside FARP.")
info("Scene should complete in ~30 s with: Invisible FARP + tyres + trucks + tent + ammo + guards + light.")

trigger.action.outText(TAG .. " ✅ DONE", 20, true)
return TAG .. " SETUP OK step=" .. step
