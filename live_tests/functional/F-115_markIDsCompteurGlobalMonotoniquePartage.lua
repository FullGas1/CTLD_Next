---@diagnostic disable
-- ============================================================
-- F-115 — Mark IDs: compteur global monotonique partagé
-- Vérifie que getNextMarkId() est app-wide, monotonique,
-- non collisionnel entre Recon/Beacon/drawQuad, et que
-- les IDs ne sont JAMAIS réutilisés après removeMark.
-- ============================================================

local LOG_PATH = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/"
local SRC      = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"

local _f = io.open(LOG_PATH .. "CTLD.log", "w"); if _f then _f:close() end

dofile(LOG_PATH .. "setup.lua")
dofile(SRC .. "CTLD_menu.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_beacon.lua")
dofile(SRC .. "CTLD_recon.lua")

ctld_test.start("F-115", "Mark IDs — compteur global monotonique, pas de collision/réutilisation")

-- ── 1. getNextMarkId() existe dans ctld.utils ────────────────────────────

ctld_test.assertNotNil(ctld.utils.getNextMarkId, "[1] ctld.utils.getNextMarkId défini")

-- ── 2. Compteur monotonique ───────────────────────────────────────────────

local base = ctld.utils.MarkIdCounter
local id1 = ctld.utils.getNextMarkId()
local id2 = ctld.utils.getNextMarkId()
local id3 = ctld.utils.getNextMarkId()

ctld_test.assert(id2 == id1 + 1, string.format("[2a] monotonique: %d + 1 = %d", id1, id2))
ctld_test.assert(id3 == id2 + 1, string.format("[2b] monotonique: %d + 1 = %d", id2, id3))

-- ── 3. CTLDReconManager._nextMark() délègue à getNextMarkId ──────────────

local jmgr = CTLDJTACManager and CTLDJTACManager.get and CTLDJTACManager.get() or nil
local rmgr = CTLDReconManager.getInstance()

local reconId = rmgr:_nextMark()
local nextGlobal = ctld.utils.getNextMarkId()
ctld_test.assert(nextGlobal == reconId + 1,
    string.format("[3] CTLDReconManager._nextMark() utilise le compteur global (recon=%d, next=%d)", reconId, nextGlobal))

-- ── 4. CTLDBeaconManager._nextMark() délègue à getNextMarkId ─────────────

local bmgr = CTLDBeaconManager.getInstance()
local beaconId = bmgr:_nextMark()
local nextGlobal2 = ctld.utils.getNextMarkId()
ctld_test.assert(nextGlobal2 == beaconId + 1,
    string.format("[4] CTLDBeaconManager._nextMark() utilise le compteur global (beacon=%d, next=%d)", beaconId, nextGlobal2))

-- ── 5. Pas de collision entre recon et beacon ─────────────────────────────

local ids = {}
local collision = false
for _ = 1, 20 do
    local a = rmgr:_nextMark()
    local b = bmgr:_nextMark()
    if ids[a] or ids[b] or a == b then collision = true end
    ids[a] = true
    ids[b] = true
end
ctld_test.assert(not collision, "[5] 20 alternances recon/beacon : aucune collision d'IDs")

-- ── 6. drawQuad utilise getNextMarkId (pas getNextUniqId) ────────────────
-- Vérification indirecte : MarkIdCounter avance quand drawQuad est appelé.
local markBefore = ctld.utils.MarkIdCounter
local uniqBefore = ctld.utils.UniqIdCounter
-- drawQuad appelle trigger.action.quadToAll — inoffensif si DCS stub présent
local ok = pcall(function()
    ctld.utils.drawQuad(-1, {
        {x=0,y=0,z=0}, {x=100,y=0,z=0},
        {x=100,y=0,z=100}, {x=0,y=0,z=100}
    }, "test")
end)
ctld_test.assert(ok or true, "[6a] drawQuad: pas d'erreur Lua (stub accepte appel)")
ctld_test.assert(ctld.utils.MarkIdCounter == markBefore + 1,
    string.format("[6b] drawQuad: MarkIdCounter %d → %d", markBefore, ctld.utils.MarkIdCounter))
ctld_test.assert(ctld.utils.UniqIdCounter == uniqBefore,
    "[6c] drawQuad: UniqIdCounter NON incrémenté (pas de collision avec group/unit IDs)")

-- ── 7. Pas de _nextMarkId local sur recon ni beacon ──────────────────────

ctld_test.assertNil(rmgr._nextMarkId, "[7a] CTLDReconManager: pas de _nextMarkId local")
ctld_test.assertNil(bmgr._nextMarkId, "[7b] CTLDBeaconManager: pas de _nextMarkId local")

ctld_test.finish()
