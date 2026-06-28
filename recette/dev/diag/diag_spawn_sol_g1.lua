-- diag/diag_spawn_sol_g1.lua
-- Utility: (re)spawn BLUE enemy group "Sol_g-1" at its original mission position.
-- Used by scenario_jtac_vehicle.lua (RED JTAC vs BLUE enemy).
--
-- Group model:  Sol_g-1 / unit Sol_g-1-1
-- Unit type:    LAV-25
-- Country:      2 (USA)
-- Origin pos:   10km south of Batumi, 500m east of Sol_g-2 (away from helo spawn)
--               land_h=893m @ (-366437, 618711)

local GNAME   = "Sol_g-1"
local UNAME   = "Sol_g-1-1"
local UTYPE   = "LAV-25"
local COUNTRY = 2
local OX, OY, OZ = -366437, 893.2, 618711

local existing = Group.getByName(GNAME)
if existing and existing:isExist() then existing:destroy() end

coalition.addGroup(COUNTRY, Group.Category.GROUND, {
    id         = ctld.utils.getNextUniqId(),
    name       = GNAME,
    task       = "Ground Nothing",
    start_time = 0,
    units      = {{
        id             = ctld.utils.getNextUniqId(),
        name           = UNAME,
        type           = UTYPE,
        x              = OX,
        y              = OZ,
        heading        = 0,
        skill          = "Average",
        playerCanDrive = false,
    }},
    route = { points = {{
        x = OX, y = OZ, type = "Turning Point", action = "Off Road", speed = 0, alt = OY,
    }}},
})

return string.format("Sol_g-1 spawned at (%.0f, %.0f)", OX, OZ)
