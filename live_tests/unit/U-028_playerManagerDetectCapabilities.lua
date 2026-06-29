---@diagnostic disable
-- ============================================================
-- U-28 : CTLDPlayerManager._detectCapabilities
-- Module  : M7 (src/CTLD_player.lua)
-- Objectif: Vérifier la détection isTransport / canCarryVehicles :
--   - UH-1H   : isTransport=true,  canCarryVehicles=false
--   - Hercules : isTransport=true,  canCarryVehicles=true
--   - F-16C_50 : isTransport=false, canCarryVehicles=false
-- Précondition : aucun transport requis (mock uniquement).
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_player.lua")

ctld_test.start("U-28", "_detectCapabilities — isTransport + canCarryVehicles")

CTLDPlayerManager._instance  = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDPlayerManager.getInstance()

local function mockUnit(typeName)
    local u = { _type = typeName }
    function u:getTypeName() return self._type end
    return u
end

-- UH-1H : in unitActions, NOT in vehicleTransportEnabled
local isT, canV = mgr:_detectCapabilities(mockUnit("UH-1H"))
ctld_test.assertEqual(isT,  true,  "UH-1H: isTransport == true")
ctld_test.assertEqual(canV, false, "UH-1H: canCarryVehicles == false")

-- Hercules : in unitActions AND in vehicleTransportEnabled
local isT2, canV2 = mgr:_detectCapabilities(mockUnit("Hercules"))
ctld_test.assertEqual(isT2,  true, "Hercules: isTransport == true")
ctld_test.assertEqual(canV2, true, "Hercules: canCarryVehicles == true")

-- F-16C_50 : NOT in unitActions, NOT in vehicleTransportEnabled
local isT3, canV3 = mgr:_detectCapabilities(mockUnit("F-16C_50"))
ctld_test.assertEqual(isT3,  false, "F-16C_50: isTransport == false")
ctld_test.assertEqual(canV3, false, "F-16C_50: canCarryVehicles == false")

ctld_test.finish()
