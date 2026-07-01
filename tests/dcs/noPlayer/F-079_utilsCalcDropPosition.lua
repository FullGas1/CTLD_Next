---@diagnostic disable
-- ============================================================
-- F-79 : ctld.utils.calcDropPosition
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: descentTime == AGL/rate ; position décalée dans le sens de la vitesse
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("F-79", "ctld.utils calcDropPosition")

-- ── Mocks ─────────────────────────────────────────────────────
local _origGetHeight = land.getHeight
land.getHeight = function(pos) return 0 end   -- terrain plat à 0m

-- Transport : alt 1000m MSL, vitesse 100 m/s vers le Nord (x), z=0
local mockTransport = {
    getPoint    = function() return { x = 0, y = 1000, z = 0 } end,
    getVelocity = function() return { x = 100, y = 0,  z = 0 } end,
}

local descentRate = 10   -- m/s → descentTime = 1000/10 = 100s

-- ── Test ──────────────────────────────────────────────────────
local landPos, descentTime = ctld.utils.calcDropPosition(mockTransport, descentRate)

-- T1: descentTime déterministe
ctld_test.assertEqual(descentTime, 100, "T1: descentTime == AGL/rate == 100s")

-- T2: position retournée non-nil
ctld_test.assertNotNil(landPos, "T2: landPos non-nil")

-- T3: y == land.getHeight() (terrain 0m)
ctld_test.assertEqual(landPos.y, 0, "T3: landPos.y == 0 (terrain flat mock)")

-- T4: inertia x : vel.x * 0.3 * time = 100 * 0.3 * 100 = 3000m → position x > 2900 (drift max 80m)
-- On vérifie que le déplacement inertiel domine
ctld_test.assert(landPos.x > 2900, "T4: landPos.x > 2900 (inertia vers le Nord)")

-- T5: inertia z nulle → z très proche de 0 (drift aléatoire ≤ 80m)
ctld_test.assert(math.abs(landPos.z) <= 80 + 1, "T5: landPos.z dans plage drift (≤ 80m)")

-- Restore
land.getHeight = _origGetHeight

ctld_test.finish()
