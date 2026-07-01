---@diagnostic disable
-- ============================================================
-- F-13 : CTLDFOBManager onDead → intégrité + OnFOBDestroyed
-- Module  : M4 (src/CTLD_fob.lua)
-- Objectif: Vérifier que :
--   - La mort d'un objet scène met à jour l'intégrité du FOB
--   - OnFOBDestroyed n'est PAS publié tant que integrity >= (1 - threshold)
--   - OnFOBDestroyed EST publié dès que integrity < (1 - threshold)
--   - Le FOB est retiré de _fobs après destruction
--   - La zone logistique est désenregistrée du ZoneManager
--
-- Stratégie :
--   Créer un FOB manuellement avec 4 objets mock (état mutable).
--   Simuler des appels onDead successifs et vérifier le comportement.
--   fobDestructionThreshold = 0.5 → seuil = integrity < 0.5 (i.e. < 2/4)
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

if not CTLDCrateManager then
    CTLDCrateManager = { getInstance = function() return {} end }
end
if not CTLDSceneManager then
    CTLDSceneManager = { getInstance = function() return {} end }
end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_fob.lua")

ctld_test.start("F-13", "CTLDFOBManager onDead → intégrité + OnFOBDestroyed")

-- Reset singletons
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDZoneManager._instance    = nil
CTLDFOBManager._instance     = nil

-- Config : threshold 0.5 → OnFOBDestroyed si integrity < 0.5
CTLDConfig.get().settings["fobDestructionThreshold"] = 0.5

local fm = CTLDFOBManager.getInstance()
local zm = CTLDZoneManager.getInstance()

-- Objets mock avec état mutable
local alives = { true, true, true, true }
local objNames = { "fob_f13_a", "fob_f13_b", "fob_f13_c", "fob_f13_d" }
local objs = {}
for i = 1, 4 do
    local idx = i
    objs[i] = {
        isExist = function() return alives[idx] end,
        getName = function() return objNames[idx] end,
    }
end

-- Créer un FOB manuellement et l'enregistrer dans le manager
local fobId = "fob_f13_test"
local fobPos = { x = 60000, y = 10, z = 60000 }
local fob = CTLDFOB:new({
    fobId        = fobId,
    name         = "FOB F13 Test",
    coalitionId  = 2,
    countryId    = 2,
    position     = fobPos,
    sceneObjects = objs,
})
fm._fobs[fobId] = fob

-- Populate reverse lookup
for _, obj in ipairs(objs) do
    fm._objectToFOB[obj:getName()] = fobId
end

-- Enregistrer la zone logistique (comme _onFOBBuilt l'aurait fait)
zm:registerFOBAsLogistic("FOB F13 Test", fobPos, 150, 2)

-- Vérifier état initial
ctld_test.assert(fob:isAlive(), "état initial : FOB vivant")
ctld_test.assertEqual(fob:getIntegrityPercent(), 1.0, "état initial : integrity == 1.0")
ctld_test.assertNotNil(zm:getLogisticZoneAtPoint(fobPos, 2), "zone logistique présente initialement")

-- Capturer OnFOBDestroyed
local destroyedPayload = nil
EventDispatcher.getInstance():subscribe("OnFOBDestroyed", function(p)
    destroyedPayload = p
end)

-- Helper : simuler mort d'un objet via onDead
local function killObj(idx)
    alives[idx] = false
    fm:onDead({ initiator = objs[idx] })
end

-- Tuer obj1 → 3/4 vivants → integrity 0.75 → pas d'event
killObj(1)
ctld_test.assertNil(destroyedPayload, "3/4 vivants (75%%) → pas d'OnFOBDestroyed")
ctld_test.assertNotNil(fm._fobs[fobId], "FOB toujours dans _fobs après 1ère mort")

-- Tuer obj2 → 2/4 vivants → integrity 0.50 → 0.50 < 0.50 = FALSE → pas d'event
killObj(2)
ctld_test.assertNil(destroyedPayload, "2/4 vivants (50%%) → pas d'OnFOBDestroyed (seuil strict <)")
ctld_test.assertNotNil(fm._fobs[fobId], "FOB toujours dans _fobs après 2ème mort")

-- Tuer obj3 → 1/4 vivants → integrity 0.25 → 0.25 < 0.50 → OnFOBDestroyed
killObj(3)
ctld_test.assertNotNil(destroyedPayload, "1/4 vivant (25%%) → OnFOBDestroyed publié")

if destroyedPayload then
    ctld_test.assertEqual(destroyedPayload.fob.fobId, fobId, "payload.fob.fobId correct")
    ctld_test.assertEqual(destroyedPayload.fob.coalitionId, 2, "payload coalition correct")
    ctld_test.assertNotNil(destroyedPayload.destruction, "payload.destruction présent")
    if destroyedPayload.destruction then
        ctld_test.assert(
            destroyedPayload.destruction.integrityPercent < 0.5,
            string.format("integrityPercent < 0.5 (got %.2f)",
                destroyedPayload.destruction.integrityPercent or -1))
        ctld_test.assertEqual(destroyedPayload.destruction.objectsTotal, 4,
            "objectsTotal == 4")
    end
    ctld_test.assertNotNil(destroyedPayload.logisticZone, "payload.logisticZone présent")
    ctld_test.assert(destroyedPayload.durationAlive >= 0, "durationAlive >= 0")
end

-- FOB retiré de _fobs
ctld_test.assertNil(fm._fobs[fobId], "FOB retiré de _fobs après destruction")

-- Zone logistique désenregistrée
ctld_test.assertNil(zm:getLogisticZoneAtPoint(fobPos, 2),
    "zone logistique absente dans ZoneManager après destruction")

-- Reverse lookup nettoyé
ctld_test.assertNil(fm._objectToFOB["fob_f13_a"], "reverse lookup obj1 nettoyé")
ctld_test.assertNil(fm._objectToFOB["fob_f13_b"], "reverse lookup obj2 nettoyé")
ctld_test.assertNil(fm._objectToFOB["fob_f13_c"], "reverse lookup obj3 nettoyé")
ctld_test.assertNil(fm._objectToFOB["fob_f13_d"], "reverse lookup obj4 nettoyé")

ctld_test.finish()
