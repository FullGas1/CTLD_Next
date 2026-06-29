---@diagnostic disable
-- ============================================================
-- F-33 : CTLDTroopManager.loadFromZone — guards + success
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("F-33", "loadFromZone — guards + success")

CTLDConfig.get().settings["loadableGroups"]        = {
    { name = "Alpha Squad", inf = 3, mg = 1, at = 0, aa = 0, mortar = 0, jtac = 0 },
}
CTLDConfig.get().settings["numberOfTroops"]        = 10
CTLDConfig.get().settings["nbLimitSpawnedTroops"]  = { 0, 0 }  -- no global limit

local mgr = CTLDTroopManager.getInstance():init()
local unit = ctld_test.getTransport()
if not unit then ctld_test.finish() return end

local unitName  = unit:getName()
local coalition = unit:getCoalition()
local typeName  = unit:getTypeName()

-- Build a valid mock pickup zone
local function makeZone(overrides)
    local z = {
        zoneName  = "TRZ_test",
        flagName  = "test_flag",
        coalition = 0,   -- neutral (all coalitions)
        active    = true,
        limit     = -1,  -- unlimited
    }
    for k, v in pairs(overrides or {}) do z[k] = v end
    return z
end

local template = CTLDConfig.get().settings["loadableGroups"][1]

-- Guard: zone not active
local r1 = mgr:loadFromZone(unit, makeZone({ active = false }), template)
ctld_test.assert(not r1, "loadFromZone → false si zone inactive")
ctld_test.assert(not mgr:hasTroops(unitName), "pas de troupes chargées si zone inactive")

-- Guard: zone limit == 0 (depleted)
local r2 = mgr:loadFromZone(unit, makeZone({ limit = 0 }), template)
ctld_test.assert(not r2, "loadFromZone → false si limit == 0")

-- Guard: template too large for transport
local bigTemplate = { name="BigGrp", inf=20, mg=5, at=0, aa=0, mortar=0, jtac=0, total=25, hasJtac=false, _dbKey="k" }
local r3 = mgr:loadFromZone(unit, makeZone(), bigTemplate)
ctld_test.assert(not r3, "loadFromZone → false si template trop grand pour le transport")

-- Guard: coalition mismatch (zone RED, unit BLUE)
local r4 = mgr:loadFromZone(unit, makeZone({ coalition = 1 }), template)  -- 1=RED
ctld_test.assert(not r4, "loadFromZone → false si coalition incompatible")

-- Success: valid zone + template fits
local r5 = mgr:loadFromZone(unit, makeZone(), template)
ctld_test.assert(r5, "loadFromZone → true (zone valide + template ok)")
ctld_test.assert(mgr:hasTroops(unitName), "hasTroops == true après loadFromZone")

local grp = mgr:getInTransit(unitName)
ctld_test.assertNotNil(grp,                                    "getInTransit retourne le groupe")
ctld_test.assertEqual(grp.templateName, "Alpha Squad",         "templateName == Alpha Squad")
ctld_test.assertEqual(grp.unitTotal,    4,                     "unitTotal == 4")
ctld_test.assertEqual(grp.state,        CTLDTroopGroup.STATE.LOADED, "état == LOADED")

-- Guard: already has troops
local r6 = mgr:loadFromZone(unit, makeZone(), template)
ctld_test.assert(not r6, "loadFromZone → false si déjà des troupes")

-- Limit decrement: zone with limit = 2
mgr._inTransit[unitName] = nil   -- reset for this sub-test
local limitedZone = makeZone({ limit = 2 })
mgr:loadFromZone(unit, limitedZone, template)
ctld_test.assertEqual(limitedZone.limit, 1, "zone.limit décrémenté de 1 après load")

ctld_test.finish()
