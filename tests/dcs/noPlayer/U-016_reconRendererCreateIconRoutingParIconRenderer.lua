---@diagnostic disable
-- ============================================================
-- U-16 : CTLDReconRenderer.createIcon — routing par iconRenderer
-- Module  : M3 (src/CTLD_recon.lua)
-- Objectif: Vérifier que createIcon appelle la bonne fonction de
--           dessin selon target.layer.iconRenderer.
--           On intercepte les appels trigger.action.* avec des stubs
--           pour compter les primitives dessinées.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_recon.lua")

ctld_test.start("U-16", "CTLDReconRenderer.createIcon — routing par iconRenderer")

-- Stub trigger.action pour compter les appels de dessin
local drawLog = {}
local origCircle = trigger.action.circleToAll
local origLine   = trigger.action.lineToAll
local origRect   = trigger.action.rectToAll

trigger.action.circleToAll = function(...) drawLog[#drawLog + 1] = "circle" end
trigger.action.lineToAll   = function(...) drawLog[#drawLog + 1] = "line"   end
trigger.action.rectToAll   = function(...) drawLog[#drawLog + 1] = "rect"   end

local function resetLog() drawLog = {} end

local pos   = { x = 0, y = 0, z = 0 }
local color = { 1, 0, 0, 1 }

-- Helpers
local function makeTarget(renderer)
    return {
        position = pos,
        layer    = { iconRenderer = renderer, color = color },
    }
end

-- infantry → circle + line + line (3 primitives)
resetLog()
CTLDReconRenderer.createIcon(makeTarget("infantry"), 1)
ctld_test.assertEqual(#drawLog, 3,          "infantry : 3 primitives dessinées")
ctld_test.assertEqual(drawLog[1], "circle", "infantry : première primitive = circle")

-- vehicle → rect + line (2 primitives)
resetLog()
CTLDReconRenderer.createIcon(makeTarget("vehicle"), 2)
ctld_test.assertEqual(#drawLog, 2,        "vehicle : 2 primitives")
ctld_test.assertEqual(drawLog[1], "rect", "vehicle : première primitive = rect")

-- aa → line + line + line (3 primitives)
resetLog()
CTLDReconRenderer.createIcon(makeTarget("aa"), 3)
ctld_test.assertEqual(#drawLog, 3,        "aa : 3 primitives")
ctld_test.assertEqual(drawLog[1], "line", "aa : première primitive = line")

-- aircraft → line + line + circle (3 primitives)
resetLog()
CTLDReconRenderer.createIcon(makeTarget("aircraft"), 4)
ctld_test.assertEqual(#drawLog, 3,          "aircraft : 3 primitives")
ctld_test.assertEqual(drawLog[3], "circle", "aircraft : 3ème primitive = circle")

-- helicopter → circle + line + line (3 primitives)
resetLog()
CTLDReconRenderer.createIcon(makeTarget("helicopter"), 5)
ctld_test.assertEqual(#drawLog, 3,          "helicopter : 3 primitives")
ctld_test.assertEqual(drawLog[1], "circle", "helicopter : première = circle")

-- ship → rect + line + line (3 primitives)
resetLog()
CTLDReconRenderer.createIcon(makeTarget("ship"), 6)
ctld_test.assertEqual(#drawLog, 3,        "ship : 3 primitives")
ctld_test.assertEqual(drawLog[1], "rect", "ship : première = rect")

-- renderer inconnu → fallback circle (1 primitive)
resetLog()
CTLDReconRenderer.createIcon(makeTarget("unknown_xyz"), 7)
ctld_test.assertEqual(#drawLog, 1,          "fallback inconnu : 1 primitive")
ctld_test.assertEqual(drawLog[1], "circle", "fallback inconnu : primitive = circle")

-- Restaurer les fonctions originales
trigger.action.circleToAll = origCircle
trigger.action.lineToAll   = origLine
trigger.action.rectToAll   = origRect

ctld_test.finish()
