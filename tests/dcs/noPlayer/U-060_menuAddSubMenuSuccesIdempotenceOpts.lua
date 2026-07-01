---@diagnostic disable
-- ============================================================
-- U-60 : ctld.Menu — addSubMenu succès + idempotence + opts
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: création nœud, idempotence, opts order/enabled
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-60", "ctld.Menu addSubMenu succes + idempotence + opts")

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)

-- T1: création simple à la racine
local r1 = menu:addSubMenu({}, "CTLD Commands")
ctld_test.assert(r1.success,            "T1a: success=true")
ctld_test.assertNotNil(r1.subMenuId,    "T1b: subMenuId non-nil")
ctld_test.assertEqual(#menu.children, 1, "T1c: 1 enfant à la racine")

-- T2: idempotence — second appel, même résultat
local r2 = menu:addSubMenu({}, "CTLD Commands")
ctld_test.assert(r2.success,            "T2a: deuxième appel success=true")
ctld_test.assertEqual(r2.subMenuId, r1.subMenuId, "T2b: même subMenuId retourné")
ctld_test.assertEqual(#menu.children, 1, "T2c: toujours 1 seul enfant (pas de doublon)")

-- T3: opts.order appliqué sur le nœud
menu:addSubMenu({}, "Ordered Section", { order = 42 })
local node = menu:_getNode({"Ordered Section"})
ctld_test.assertEqual(node and node.order, 42, "T3: opts.order == 42 sur le nœud")

-- T4: opts.enabled=false → nœud masqué mais présent en mémoire
menu:addSubMenu({}, "Hidden Section", { enabled = false })
local hiddenNode = menu:_getNode({"Hidden Section"})
ctld_test.assertNotNil(hiddenNode,                  "T4a: nœud disabled présent en mémoire")
ctld_test.assert(hiddenNode.enabled == false,        "T4b: enabled == false sur le nœud")

-- T5: sans opts.enabled → enabled == true par défaut
local defaultNode = menu:_getNode({"CTLD Commands"})
ctld_test.assert(defaultNode and defaultNode.enabled == true, "T5: enabled == true par défaut")

ctld_test.finish()
