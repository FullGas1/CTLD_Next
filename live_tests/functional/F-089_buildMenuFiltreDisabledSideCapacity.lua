---@diagnostic disable
-- ============================================================
-- F-89 : buildMenu — filtre disabled + side + capacity
-- Module  : Feature D (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
local mgr = dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/_fd_setup.lua")

ctld_test.start("F-89", "buildMenu — disabled / side / capacity filter")

-- Add custom templates with various side/size/disabled states
mgr:createLoadableGroup({ name = "BLUE Recon",   composition = { inf = 4, jtac = 1 }, side = 2 })
mgr:createLoadableGroup({ name = "RED AT",        composition = { inf = 2, at = 6  }, side = 1 })
mgr:createLoadableGroup({ name = "Big Squad",     composition = { inf = 20 } })       -- oversized
mgr:createLoadableGroup({ name = "Hidden",        composition = { inf = 3 } })         -- will disable
mgr:disableLoadableGroup("Hidden")
mgr:disableLoadableGroup("JTAC Group")   -- disable one standard

-- Spy on addCommandForGroup calls
local loaded_labels = {}
missionCommands.addCommandForGroup = function(gid, label, path, fn, arg)
    if label and label:find("Load ") then
        table.insert(loaded_labels, label)
    end
end

-- Simulate a BLUE UH-1H (capacity 10) calling buildMenu
local fakeUnit = {
    getName       = function() return "BLUE_UH1H_1" end,
    getTypeName   = function() return "UH-1H" end,
    getCoalition  = function() return 2 end,   -- BLUE
    getGroup      = function()
        return { getID = function() return 1 end }
    end,
}
CTLDConfig.get().settings["numberOfTroops"] = 10

mgr:buildMenu(fakeUnit, 1, {})

-- Expected in menu: "Standard Group" (6+2+2=10, BLUE ok), "BLUE Recon" (5, BLUE ok)
-- NOT expected: "JTAC Group" (disabled), "Hidden" (disabled),
--               "RED AT" (side=1, wrong coalition), "Big Squad" (20 > 10)

local function inMenu(name)
    for _, lbl in ipairs(loaded_labels) do
        if lbl:find(name, 1, true) then return true end
    end
    return false
end

ctld_test.assert(inMenu("Standard Group"), "Standard Group in menu (10 <= cap, BLUE ok)")
ctld_test.assert(inMenu("BLUE Recon"),     "BLUE Recon in menu (5 <= cap, side=2)")

ctld_test.assert(not inMenu("JTAC Group"), "JTAC Group excluded (disabled)")
ctld_test.assert(not inMenu("Hidden"),     "Hidden excluded (disabled)")
ctld_test.assert(not inMenu("RED AT"),     "RED AT excluded (side=1, BLUE unit)")
ctld_test.assert(not inMenu("Big Squad"),  "Big Squad excluded (20 > cap 10)")

ctld_test.assertEqual(#loaded_labels, 2, "exactly 2 Load entries in menu")

ctld_test.finish()
