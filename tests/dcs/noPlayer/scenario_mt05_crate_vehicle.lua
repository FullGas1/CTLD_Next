---@diagnostic disable
-- ============================================================
-- MT-05 AUTO — Crate + véhicule entier : isolation croisée
-- ============================================================
-- Vérifie que charger une crate ET un véhicule entier simultanément
-- sur le même transport n'entraîne aucune interférence d'état.
-- Pas de spawn DCS réel — test sur les registres internes uniquement.
--
-- Pré-requis : aucun (entièrement mocké)
-- Famille    : auto (aucune intervention humaine)
-- ============================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-05] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_MT05_RUNNING then
    trigger.action.outText("[MT-05] already running.", 10)
    return Witchcraft
end
_SCN_MT05_RUNNING = true

do  -- isolation scope
trigger.action.outText("[MT-05] START — crate + véhicule entier isolation", 8)

local TRANSPORT_NAME = "mock_transport_MT05"
local CRATE_NAME     = "mock_crate_MT05"
local VEHICLE_ID     = 99901
local VEHICLE_TYPE   = "M1045 HMMWV TOW"
local CRATE_WEIGHT   = 2000

-- ── Mock transport unit ──────────────────────────────────────
local mockTransport = {
    getName  = function() return TRANSPORT_NAME end,
    getPoint = function() return { x = 0, y = 0, z = 0 } end,
}

-- ── Setup ────────────────────────────────────────────────────
local cm = CTLDCrateManager.getInstance()
local vs = CTLDVehicleSpawner.getInstance()

-- Mock descriptor with known weight
local mockDescriptor = { desc = "Mock Hummer", weight = CRATE_WEIGHT, unitTypes = { VEHICLE_TYPE } }

-- Register crate in LOADED state
local crate = CTLDCrate:new({
    crateName   = CRATE_NAME,
    descriptor  = mockDescriptor,
    spawnMethod = "ctld",
    position    = { x = 0, y = 0, z = 0 },
    heading     = 0,
    coalition   = 2,
})
crate:load(mockTransport)
cm.crates[CRATE_NAME] = crate

-- Register vehicle in LOADED state
local vehicle = CTLDVehicle:new({
    id          = VEHICLE_ID,
    vehicleType = VEHICLE_TYPE,
    spawnData   = nil,
})
vehicle:setState(CTLDVehicle.STATE.LOADED)
vehicle.loadTransportName = TRANSPORT_NAME
vehicle.loadMethod        = "menu_ctld"
vs._vehicles[VEHICLE_ID]  = vehicle

-- ── Test helpers ─────────────────────────────────────────────
local passed = 0
local failed = 0
local failures = {}
local function pass(_) passed = passed + 1 end
local function fail(label) failed = failed + 1; table.insert(failures, label) end
local function check(label, cond) if cond then pass(label) else fail(label) end end

-- ── F-MT05-1 : crate détectée comme chargée via CTLD ────────
check("F-MT05-1 crate isLoadedByCTLD", crate:isLoadedByCTLD() == true)

-- ── F-MT05-2 : véhicule détecté comme chargé sur transport ──
local loadedVehs = vs:findLoadedVehicles(mockTransport)
check("F-MT05-2 findLoadedVehicles returns vehicle", #loadedVehs == 1 and loadedVehs[1].id == VEHICLE_ID)

-- ── F-MT05-3 : poids crate agrégé correctement ──────────────
local crateW = cm:getLoadedCrateWeight(TRANSPORT_NAME)
check("F-MT05-3 getLoadedCrateWeight = " .. tostring(crateW), crateW == CRATE_WEIGHT)

-- ── F-MT05-4 : poids véhicule agrégé correctement ───────────
local vehicleWeights = ctld.gs("vehiclesWeight") or {}
local expectedVW = vehicleWeights[VEHICLE_TYPE] or 2500
local vehicleW = vs:getLoadedVehicleWeight(TRANSPORT_NAME)
check("F-MT05-4 getLoadedVehicleWeight = " .. tostring(vehicleW), vehicleW == expectedVW)

-- ── F-MT05-5 : unload crate → véhicule inchangé ─────────────
crate:unload()
check("F-MT05-5a crate state after unload = LANDED", crate.state == CTLDCrate.STATE.LANDED)
check("F-MT05-5b vehicle state unchanged after crate unload", vehicle:getState() == CTLDVehicle.STATE.LOADED)
check("F-MT05-5c vehicle.loadTransportName unchanged", vehicle.loadTransportName == TRANSPORT_NAME)
-- Restore crate for next tests
crate:load(mockTransport)

-- ── F-MT05-6 : unload véhicule → crate inchangée ────────────
vehicle:setState(CTLDVehicle.STATE.WAITING)
vehicle.loadTransportName = nil
check("F-MT05-6a vehicle state after unload = WAITING", vehicle:getState() == CTLDVehicle.STATE.WAITING)
check("F-MT05-6b crate isLoadedByCTLD unchanged", crate:isLoadedByCTLD() == true)
check("F-MT05-6c crate.loadedBy unchanged", crate.loadedBy ~= nil)
-- Restore vehicle for next tests
vehicle:setState(CTLDVehicle.STATE.LOADED)
vehicle.loadTransportName = TRANSPORT_NAME

-- ── F-MT05-7 : après unload crate, findLoadedVehicles intact ─
crate:unload()
local vehs7 = vs:findLoadedVehicles(mockTransport)
check("F-MT05-7 findLoadedVehicles still 1 after crate unload", #vehs7 == 1)
crate:load(mockTransport)

-- ── F-MT05-8 : après unload véhicule, crate weight intact ────
vehicle:setState(CTLDVehicle.STATE.WAITING)
vehicle.loadTransportName = nil
local crateW8 = cm:getLoadedCrateWeight(TRANSPORT_NAME)
check("F-MT05-8 getLoadedCrateWeight intact after vehicle unload", crateW8 == CRATE_WEIGHT)

-- ── Cleanup ──────────────────────────────────────────────────
cm.crates[CRATE_NAME]    = nil
vs._vehicles[VEHICLE_ID] = nil

-- ── Résultat ─────────────────────────────────────────────────
local total = passed + failed
local msg = string.format("[MT-05] %d/%d PASS", passed, total)
trigger.action.outText(msg, 12, true)
ctld.utils.log("INFO", msg)
if failed > 0 then
    ctld.utils.log("ERROR", "[MT-05] FAILED tests: " .. failed)
end

if #failures > 0 then
    msg = msg .. " | FAIL: " .. table.concat(failures, ", ")
end
_SCN_MT05_RUNNING = false
return msg
end  -- do isolation scope
return Witchcraft
