---@diagnostic disable
-- ============================================================
-- U-56 : CTLDObjectRegistry — spawnObject() GROUND
-- Module  : P1 (src/core/CTLD_objectRegistry.lua)
-- Objectif: Vérifier spawnObject pour groupes GROUND :
--   nombre d'unités, résolution coalition-aware unitType,
--   calcul des positions (rotation par heading)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")

ctld_test.start("U-56", "CTLDObjectRegistry spawnObject() GROUND")

-- ── Mock coalition.addGroup ───────────────────────────────────
local _groupCalls = {}
local _origAddGroup = coalition.addGroup
coalition.addGroup = function(countryId, category, groupData)
    table.insert(_groupCalls, { countryId = countryId, category = category, groupData = groupData })
    return { getName = function() return groupData.name end }
end

local function approxEq(a, b, eps)
    return math.abs(a - b) < (eps or 0.001)
end

-- ── T1: FARP_Security_Guard BLUE — 3 unités ─────────────────
local result = CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, 0)
ctld_test.assertNotNil(result,                "T1a: spawnObject(FARP_Security_Guard) non-nil")
ctld_test.assertEqual(#_groupCalls, 1,        "T1b: coalition.addGroup called once")

local gd = _groupCalls[1] and _groupCalls[1].groupData
ctld_test.assertNotNil(gd,                    "T1c: groupData non-nil")
ctld_test.assertEqual(#(gd and gd.units or {}), 3, "T1d: 3 units in group")

-- ── T2: coalition-aware unitType (BLUE → Soldier M4) ─────────
local u1 = gd and gd.units[1]
ctld_test.assertEqual(u1 and u1.type, "Soldier M4", "T2a: BLUE unit[1].type == Soldier M4")
local u2 = gd and gd.units[2]
ctld_test.assertEqual(u2 and u2.type, "Soldier M4", "T2b: BLUE unit[2].type == Soldier M4")

-- ── T3: coalition-aware unitType (RED → Infantry AK) ─────────
_groupCalls = {}
CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.RED, 0, 0, 0, 0)
local gd_red = _groupCalls[1] and _groupCalls[1].groupData
local r1 = gd_red and gd_red.units[1]
ctld_test.assertEqual(r1 and r1.type, "Infantry AK", "T3: RED unit[1].type == Infantry AK")

-- ── T4: positions heading=0 (no rotation) ────────────────────
-- unit[1]: dx=0, dz=0 → ux=0, uz=0
-- unit[2]: dx=3, dz=1 → ux=3, uz=1
local u1_pos = gd and gd.units[1]
ctld_test.assert(approxEq(u1_pos and u1_pos.x or 99, 0), "T4a: unit[1].x == 0 (no offset)")
ctld_test.assert(approxEq(u1_pos and u1_pos.y or 99, 0), "T4b: unit[1].y == 0 (no offset)")

local u2_pos = gd and gd.units[2]
ctld_test.assert(approxEq(u2_pos and u2_pos.x or 99, 3), "T4c: unit[2].x == 3 (dx=3, heading=0)")
ctld_test.assert(approxEq(u2_pos and u2_pos.y or 99, 1), "T4d: unit[2].y == 1 (dz=1, heading=0)")

-- ── T5: positions heading=π/2 (90°) — rotation applied ───────
-- cosH=0, sinH=1 → ux = x - dz, uz = z + dx
-- unit[2]: dx=3, dz=1 → ux = 0-1 = -1, uz = 0+3 = 3
_groupCalls = {}
CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, math.pi / 2)
local gd_rot = _groupCalls[1] and _groupCalls[1].groupData
local u2_rot = gd_rot and gd_rot.units[2]
ctld_test.assert(approxEq(u2_rot and u2_rot.x or 99, -1), "T5a: unit[2].x == -1 (rotated 90°)")
ctld_test.assert(approxEq(u2_rot and u2_rot.y or 99,  3), "T5b: unit[2].y ==  3 (rotated 90°)")

-- Restore
coalition.addGroup = _origAddGroup

ctld_test.finish()
