---@diagnostic disable
-- ============================================================
-- F-80 : ctld.utils.getSpawnObjectPositions
-- Module  : M9 (src/CTLD_utils.lua)
-- Objectif: structure résultat, n positions, spacing, clock valide
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("F-80", "ctld.utils getSpawnObjectPositions")

-- ── Mock Unit ─────────────────────────────────────────────────
-- Heading 0 rad (Nord), position origine
local mockUnit = {
    getPoint    = function() return { x = 0, y = 100, z = 0 } end,
    getPosition = function()
        return {
            p = { x = 0, y = 100, z = 0 },
            x = { x = 1, y = 0, z = 0 },  -- Nord
            y = { x = 0, y = 1, z = 0 },
            z = { x = 0, y = 0, z = 1 },
        }
    end,
    -- getVelocity non requis par getSpawnObjectPositions
}

-- ── T1: n=3, safeDistance=10, spacing=5 ──────────────────────
local result = ctld.utils.getSpawnObjectPositions(mockUnit, 3, 10, 5)

ctld_test.assertNotNil(result,                     "T1a: résultat non-nil")
ctld_test.assertNotNil(result.positions,            "T1b: result.positions non-nil")
ctld_test.assertEqual(#result.positions, 3,         "T1c: 3 positions générées")
ctld_test.assertEqual(result.distance, 10,          "T1d: result.distance == safeDistance == 10")

-- T2: clock est une string entre "1" et "12"
ctld_test.assertNotNil(result.clock,                "T2a: result.clock non-nil")
ctld_test.assertEqual(type(result.clock), "string", "T2b: clock est une string")
local clockNum = tonumber(result.clock)
ctld_test.assertNotNil(clockNum,                    "T2c: clock convertible en number")
ctld_test.assert(clockNum >= 1 and clockNum <= 12,  "T2d: clock entre 1 et 12")

-- T3: chaque position est une table {x, z}
for i, pos in ipairs(result.positions) do
    ctld_test.assertNotNil(pos.x, "T3a: position["..i.."].x non-nil")
    ctld_test.assertNotNil(pos.z, "T3b: position["..i.."].z non-nil")
end

-- T4: spacing — distance entre positions consécutives ≈ 5m
-- Toutes les positions sont sur le même axe, donc dist[i+1] - dist[i] ≈ spacing
-- On mesure en distance depuis l'origine le long du vecteur de l'axe aléatoire
-- (on ne peut pas vérifier l'angle, mais on peut vérifier que les points divergent)
local p1, p2, p3 = result.positions[1], result.positions[2], result.positions[3]
local function dist2D(a, b)
    return math.sqrt((a.x-b.x)^2 + (a.z-b.z)^2)
end
local d12 = dist2D(p1, p2)
local d23 = dist2D(p2, p3)
ctld_test.assert(math.abs(d12 - 5) < 0.01, "T4a: distance p1→p2 ≈ spacing (5m)")
ctld_test.assert(math.abs(d23 - 5) < 0.01, "T4b: distance p2→p3 ≈ spacing (5m)")

ctld_test.finish()
