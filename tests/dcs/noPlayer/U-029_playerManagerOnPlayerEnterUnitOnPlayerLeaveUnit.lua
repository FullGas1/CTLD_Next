---@diagnostic disable
-- ============================================================
-- U-29 : CTLDPlayerManager — onPlayerEnterUnit + onPlayerLeaveUnit
-- Module  : M7 (src/CTLD_player.lua)
-- Objectif: Vérifier avec un mock unit que :
--   1. onPlayerEnterUnit crée le CTLDPlayer dans _players
--   2. Les propriétés (unitName, typeName, isTransport) sont correctes
--   3. onPlayerLeaveUnit supprime le joueur de _players
-- Le menu DCS (missionCommands) peut échouer silencieusement
-- avec un groupId factice — ce n'est pas l'objet de ce test.
-- Précondition : aucun transport requis (mock uniquement).
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_player.lua")

ctld_test.start("U-29", "onPlayerEnterUnit + onPlayerLeaveUnit — état _players")

CTLDPlayerManager._instance  = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDPlayerManager.getInstance()

-- Mock DCS Unit (duck-typing)
local mockGroup = { _id = 999, _name = "mock_grp_999" }
function mockGroup:getID()   return self._id   end
function mockGroup:getName() return self._name end

local mockUnit = { _name = "mock_pilot", _type = "UH-1H", _coa = coalition.side.BLUE }
function mockUnit:getName()       return self._name end
function mockUnit:getTypeName()   return self._type end
function mockUnit:getCoalition()  return self._coa  end
function mockUnit:isExist()       return true        end
function mockUnit:getPlayerName() return "MockPilot" end
function mockUnit:getGroup()      return mockGroup   end

-- onPlayerEnterUnit (buildMenu may fail silently for fake groupId — pcall)
local okEnter = pcall(function()
    mgr:onPlayerEnterUnit({ initiator = mockUnit })
end)
-- buildMenu peut échouer sur missionCommands avec groupId factice (999) — ignoré ici.
-- L'objet de ce test est l'état de _players, pas le rendu DCS.
_ = okEnter

local p = mgr:getPlayer("mock_pilot")
ctld_test.assertNotNil(p, "getPlayer('mock_pilot') retourne un CTLDPlayer")
if p then
    ctld_test.assertEqual(p.unitName,    "mock_pilot",         "unitName correct")
    ctld_test.assertEqual(p.typeName,    "UH-1H",              "typeName correct")
    ctld_test.assertEqual(p.groupId,     999,                  "groupId correct")
    ctld_test.assertEqual(p.groupName,   "mock_grp_999",       "groupName correct")
    ctld_test.assertEqual(p.coalition,   coalition.side.BLUE,  "coalition correct")
    ctld_test.assertEqual(p.isTransport, true,                 "isTransport == true (UH-1H)")
end

-- onPlayerLeaveUnit
local okLeave = pcall(function()
    mgr:onPlayerLeaveUnit({ initiator = mockUnit })
end)
ctld_test.assert(okLeave, "onPlayerLeaveUnit ne crash pas")
ctld_test.assertNil(mgr:getPlayer("mock_pilot"),
    "getPlayer('mock_pilot') == nil après onPlayerLeaveUnit")

ctld_test.finish()
