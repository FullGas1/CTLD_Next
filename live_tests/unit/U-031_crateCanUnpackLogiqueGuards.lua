---@diagnostic disable
-- ============================================================
-- U-31 : CTLDCrate.canUnpack — logique guards
-- Module  : R1 (src/CTLD_crate.lua)
-- Note    : forceCrateToBeMoved intentionally not implemented —
--           crates can be unpacked wherever they land.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("U-31", "CTLDCrate.canUnpack — logique guards")

local pos  = { x = 0, y = 0, z = 0 }
local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
local transport = { getName = function() return "heli" end }

local function makeCrate()
    return CTLDCrate:new({ crateName="c_test", descriptor=desc,
        spawnMethod="crate_spawn", position=pos, coalition=coalition.side.BLUE })
end

-- SPAWNED (on ground) → canUnpack=true (no movement constraint)
local c1 = makeCrate()
ctld_test.assert(c1:canUnpack(), "SPAWNED on ground → canUnpack true")

-- canBeUnpacked=false → always false regardless of state
c1.canBeUnpacked = false
ctld_test.assert(not c1:canUnpack(), "canBeUnpacked=false → false")

-- LOADED → isOnGround=false → false
local c2 = makeCrate()
c2:load(transport)
ctld_test.assert(not c2:canUnpack(), "LOADED → canUnpack false (not on ground)")

-- FALLING → false
local c3 = makeCrate()
c3:load(transport)
c3:drop(pos)
ctld_test.assert(not c3:canUnpack(), "FALLING → canUnpack false")

-- UNPACKED → false
local c4 = makeCrate()
c4:unpack()
ctld_test.assert(not c4:canUnpack(), "UNPACKED → canUnpack false")

ctld_test.finish()
