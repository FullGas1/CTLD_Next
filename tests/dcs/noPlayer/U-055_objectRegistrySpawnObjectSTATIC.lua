---@diagnostic disable
-- ============================================================
-- U-55 : CTLDObjectRegistry — spawnObject() STATIC
-- Module  : P1 (src/core/CTLD_objectRegistry.lua)
-- Objectif: Vérifier spawnObject pour objets STATIC (FARP, cargo...)
--   + injection des champs standard + fusion des overrides
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")

ctld_test.start("U-55", "CTLDObjectRegistry spawnObject() STATIC")

-- ── Mock coalition.addStaticObject ───────────────────────────
local _staticCalls = {}
local _origAddStatic = coalition.addStaticObject
coalition.addStaticObject = function(countryId, groupData)
    table.insert(_staticCalls, { countryId = countryId, groupData = groupData })
    -- Return a mock static object
    return { getName = function() return groupData.name end }
end

-- ── T1: spawnObject("FARP") — call made + return non-nil ─────
local result = CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 1000, 2000, 0)
ctld_test.assertNotNil(result,                "T1a: spawnObject(FARP) returns non-nil")
ctld_test.assertEqual(#_staticCalls, 1,       "T1b: coalition.addStaticObject called once")

local gd = _staticCalls[1] and _staticCalls[1].groupData
ctld_test.assertNotNil(gd,                    "T1c: groupData passed to addStaticObject")
ctld_test.assertEqual(gd and gd.x, 1000,      "T1d: x == 1000")
ctld_test.assertEqual(gd and gd.y, 2000,      "T1e: y (=z) == 2000")
ctld_test.assertEqual(gd and gd.heading, 0,   "T1f: heading == 0")
ctld_test.assertEqual(gd and gd.start_time, 0,"T1g: start_time == 0")
ctld_test.assertNotNil(gd and gd.name,        "T1h: name injected")
ctld_test.assertNotNil(gd and gd.transportable, "T1i: transportable injected")

-- groupType and namePrefix must NOT appear in groupData
ctld_test.assertNil(gd and gd.groupType,      "T1j: groupType stripped from groupData")
ctld_test.assertNil(gd and gd.namePrefix,     "T1k: namePrefix stripped from groupData")

-- descriptor field preserved (type = "FARP")
ctld_test.assertEqual(gd and gd.type, "FARP", "T1l: descriptor.type preserved")

-- ── T2: unknown key → nil, no call ───────────────────────────
local prevCount = #_staticCalls
local bad = CTLDObjectRegistry.spawnObject("__no_such_key__", coalition.side.BLUE, 2, 0, 0, 0)
ctld_test.assertNil(bad,                      "T2a: unknown key returns nil")
ctld_test.assertEqual(#_staticCalls, prevCount, "T2b: no extra addStaticObject call")

-- ── T3: overrides merged ─────────────────────────────────────
_staticCalls = {}
CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0,
    { heliport_frequency = "130.0", custom_field = "yes" })
local gd3 = _staticCalls[1] and _staticCalls[1].groupData
ctld_test.assertEqual(gd3 and gd3.heliport_frequency, "130.0", "T3a: override heliport_frequency applied")
ctld_test.assertEqual(gd3 and gd3.custom_field, "yes",          "T3b: custom override field merged")

-- Restore
coalition.addStaticObject = _origAddStatic

ctld_test.finish()
