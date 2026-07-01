---@diagnostic disable
-- ============================================================
-- F-100 : CTLDCrateManager:spawnCrate — VISUAL CHECK en mission
-- Module  : Q1 (src/CTLD_crate.lua)
-- REQUIRES: DCS mission running, BLUE player in slot
--
-- Vérifie :
--   1. Un static cargo "ammo_cargo" spawné devant le transport
--   2. Un static cargo "container_cargo" (dynamic model) spawné à gauche
--   3. StaticObject.getByName() retourne le static effectivement créé
--   4. Le crate est enregistré dans CTLDCrateManager.crates
--   5. OnCrateSpawned reçu avec les bons champs
--
-- VISUAL CHECK :
--   Deux caisses apparaissent sur la carte F10 et dans le monde
--   ~30 m devant l'hélico (load) et ~60 m devant (sling/dynamic)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

-- Purge des statics spawned par un run précédent de ce test
_CTLD_CRATE_LAST_SPAWNED = _CTLD_CRATE_LAST_SPAWNED or {}
for _, name in ipairs(_CTLD_CRATE_LAST_SPAWNED) do
    local obj = StaticObject.getByName(name)
    if obj and obj:isExist() then obj:destroy() end
end
_CTLD_CRATE_LAST_SPAWNED = {}

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC .. "CTLD_core.lua")
dofile(SRC .. "lib/CTLD_objectRegistry.lua")
dofile(SRC .. "lib/CTLDParachuteEffect.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_player.lua")
dofile(SRC .. "CTLD_menu.lua")
dofile(SRC .. "CTLD_crate.lua")
dofile(SRC .. "CTLD_troop.lua")
dofile(SRC .. "CTLD_beacon.lua")
dofile(SRC .. "CTLD_jtac.lua")
dofile(SRC .. "CTLD_vehicle.lua")

ctld_test.start("F-100", "spawnCrate — static DCS réel + VISUAL CHECK")

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local cm = CTLDCrateManager.getInstance()

-- ── Collect OnCrateSpawned events ─────────────────────────
local _spawned = {}
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(e)
    table.insert(_spawned, e)
end)

-- ── Compute spawn positions devant le transport ────────────
local tPos = transport:getPoint()
local hdg  = ctld.utils.getHeadingInRadians("F-100", transport, true)
local groundH = land.getHeight({ x = tPos.x, y = tPos.z })

local function frontOffset(dist)
    return {
        x = tPos.x + math.cos(hdg) * dist,
        y = groundH,
        z = tPos.z + math.sin(hdg) * dist,
    }
end

local pos1 = frontOffset(30)   -- "load" model
local pos2 = frontOffset(60)   -- "dynamic" model

-- ── Descriptor Humvee-MG (weight=1000.01, 1 crate) ────────
local desc = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
ctld_test.assertNotNil(desc, "findDescriptorByUnitType: descriptor trouvé")

-- ── Spawn 1 — model "load" (ammo_cargo, canCargo=false) ───
local crate1 = cm:spawnCrate(desc, pos1, coalition.side.BLUE,
    "MissionMaker", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, nil, "load")

ctld_test.assertNotNil(crate1,                         "spawnCrate load: retourne CTLDCrate")
ctld_test.assertNotNil(crate1.crateName,               "spawnCrate load: crateName assigné")

-- Static DCS réellement présent
local static1 = StaticObject.getByName(crate1.crateName)
ctld_test.assertNotNil(static1,                        "spawnCrate load: StaticObject présent en mission ✅ VISUAL")

-- Enregistré dans le manager
ctld_test.assertNotNil(cm.crates[crate1.crateName],    "spawnCrate load: enregistré dans cm.crates")

-- ── Spawn 2 — model "dynamic" (ammo_cargo, canCargo=true) ─
local crate2 = cm:spawnCrate(desc, pos2, coalition.side.BLUE,
    "MissionMaker", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, nil, "dynamic")

ctld_test.assertNotNil(crate2,                         "spawnCrate dynamic: retourne CTLDCrate")

local static2 = StaticObject.getByName(crate2.crateName)
ctld_test.assertNotNil(static2,                        "spawnCrate dynamic: StaticObject présent en mission ✅ VISUAL")

-- ── Events ────────────────────────────────────────────────
ctld_test.assertEqual(#_spawned, 2,                    "OnCrateSpawned: 2 events reçus")
ctld_test.assertEqual(_spawned[1].spawnedBy, "MissionMaker", "event 1: spawnedBy=MissionMaker")
ctld_test.assertEqual(_spawned[1].coalition, coalition.side.BLUE, "event 1: coalition=BLUE")
ctld_test.assertNotNil(_spawned[1].position,           "event 1: position présente")

-- ── Positions vérifiées (±5 m tolérance) ─────────────────
local function approx(a, b) return math.abs(a - b) < 5 end
ctld_test.assert(approx(crate1.position.x, pos1.x),   "spawnCrate load: position.x correct")
ctld_test.assert(approx(crate1.position.z, pos1.z),   "spawnCrate load: position.z correct")
ctld_test.assert(approx(crate2.position.x, pos2.x),   "spawnCrate dynamic: position.x correct")

ctld_test.finish()

-- ── Instructions VISUAL CHECK ─────────────────────────────
trigger.action.outText(
    "F-100 VISUAL CHECK (spawnCrate):\n" ..
    "  - Caisse 1 (ammo_cargo) ~30 m devant l'hélico\n" ..
    "  - Caisse 2 (dynamic ammo_cargo) ~60 m devant l'hélico\n" ..
    "  - Les deux caisses doivent apparaître sur la carte F10\n" ..
    "  - Crate 1 : " .. tostring(crate1 and crate1.crateName or "FAIL") .. "\n" ..
    "  - Crate 2 : " .. tostring(crate2 and crate2.crateName or "FAIL"), 30)

-- Sauvegarde des noms pour purge ultérieure
_CTLD_CRATE_LAST_SPAWNED = {
    crate1 and crate1.crateName or nil,
    crate2 and crate2.crateName or nil,
}
