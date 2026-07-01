-- diag/diag_spawn_sol_g2.lua
-- Utility: (re)spawn enemy group "Sol_g-2" at its original mission position.
-- Use this to restore the enemy after a scenario has destroyed or moved it.
--
-- Group model:  Sol_g-2 / unit Sol_g-2-1
-- Unit type:    Hummer
-- Country:      81 (Georgia)
-- Origin pos:   10km south of Batumi airport, on land (h=775m)
--               Batumi @ (-356437, 618211) → south = x-10000

local GNAME   = "Sol_g-2"
local UNAME   = "Sol_g-2-1"
local UTYPE   = "Hummer"
local COUNTRY = 81
local OX, OY, OZ = -366437, 775.1, 618211

-- Destroy existing instance if present (avoid duplicate group error)
local existing = Group.getByName(GNAME)
if existing and existing:isExist() then
    existing:destroy()
end

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
        y              = OZ,   -- DCS addGroup: y field = world Z axis
        heading        = 0,
        skill          = "Average",
        playerCanDrive = false,
    }},
    route = { points = {{
        x = OX, y = OZ, type = "Turning Point", action = "Off Road", speed = 0, alt = OY,
    }}},
})

return string.format("Sol_g-2 spawned at (%.0f, %.0f)", OX, OZ)
