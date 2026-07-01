---@diagnostic disable
-- ============================================================
-- F-35 : CTLDTroopManager.returnToBase
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("F-35", "returnToBase")

CTLDConfig.get().settings["loadableGroups"]       = {
    { name = "Bravo Team", inf = 2, mg = 1, at = 0, aa = 0, mortar = 0, jtac = 0 },
}
CTLDConfig.get().settings["numberOfTroops"]       = 10
CTLDConfig.get().settings["nbLimitSpawnedTroops"] = { 0, 0 }

local mgr  = CTLDTroopManager.getInstance():init()
local unit = ctld_test.getTransport()
if not unit then ctld_test.finish() return end

local unitName = unit:getName()
local template = CTLDConfig.get().settings["loadableGroups"][1]

-- Guard: no troops → false
local r0 = mgr:returnToBase(unit, { zoneName="Z", flagName="f", limit=-1 })
ctld_test.assert(not r0, "returnToBase → false si pas de troupes")

-- Load troops
local zone = { zoneName="TRZ_test", flagName="trz_flag", coalition=0, active=true, limit=3 }
mgr:loadFromZone(unit, zone, template)
ctld_test.assert(mgr:hasTroops(unitName), "troupes chargées avant returnToBase")
ctld_test.assertEqual(zone.limit, 2, "zone.limit décrémenté de 1 après load")

-- returnToBase
local r1 = mgr:returnToBase(unit, zone)
ctld_test.assert(r1, "returnToBase → true")
ctld_test.assert(not mgr:hasTroops(unitName), "hasTroops == false après returnToBase")
ctld_test.assertNil(mgr:getInTransit(unitName), "getInTransit == nil après returnToBase")

-- Zone limit incremented back by unitTotal (3)
ctld_test.assertEqual(zone.limit, 2 + template.total, "zone.limit remonté de unitTotal après return")

-- Unlimited zone (limit == -1) unchanged
mgr:loadFromZone(unit, zone, template)   -- reload (limit is now 5, ok)
local zoneUnlim = { zoneName="TRZ_unlim", flagName="uf", coalition=0, active=true, limit=-1 }
-- Inject directly to avoid zone limit check complexity
local grp2 = CTLDTroopGroup:new({ templateKey="k", templateName="T",
    unitTotal=2, weight=218, hasJtac=false,
    coalitionId=unit:getCoalition(), countryId=unit:getCountry() })
mgr._inTransit[unitName] = grp2

local r2 = mgr:returnToBase(unit, zoneUnlim)
ctld_test.assert(r2, "returnToBase → true (zone unlimited)")
ctld_test.assertEqual(zoneUnlim.limit, -1, "zone.limit unlimited (-1) inchangé")

ctld_test.finish()
