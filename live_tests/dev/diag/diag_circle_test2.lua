-- diag_circle_test2.lua
-- Minimal circleToAll debug: fixed position, maximum visibility, raw param dump.

-- Clean previous
trigger.action.removeMark(9010)
trigger.action.removeMark(9011)
trigger.action.removeMark(9012)

-- Get player position
local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then playerUnit = p; break end
end
if not playerUnit then return "NO_BLUE_PLAYER" end

local pt = playerUnit:getPoint()
local h  = land.getHeight({ x = pt.x, y = pt.z })

env.info(string.format("[diag2] player pt = x=%.1f y=%.1f z=%.1f  land.getHeight=%.1f",
    pt.x, pt.y, pt.z, h))

-- Test 1: use player's actual point (y=altitude) — maybe DCS accepts altitude too
local c_alt = { x = pt.x, y = pt.y, z = pt.z }

-- Test 2: ground-clamped vec3
local c_gnd = { x = pt.x, y = h, z = pt.z }

-- Test 3: positional color table {r,g,b,a} instead of named keys
trigger.action.circleToAll(
    coalition.side.BLUE,   -- only for BLUE
    9010,
    c_alt,                 -- altitude-based center
    3000,
    {1.0, 0.0, 0.0, 1.0}, -- RED, positional table, fully opaque border
    {1.0, 0.0, 0.0, 0.5}, -- RED fill 50% opacity
    1,                     -- solid
    false,
    "TEST1 alt-center positional-color BLUE"
)

-- Test 2: named color, ground height, coalition -1
trigger.action.circleToAll(
    -1,
    9011,
    c_gnd,
    3000,
    { r=0.0, g=1.0, b=0.0, a=1.0 }, -- GREEN named
    { r=0.0, g=1.0, b=0.0, a=0.5 },
    1,
    false,
    "TEST2 gnd-center named-color ALL"
)

-- Test 3: zero altitude, offset position
local c_zero = { x = pt.x + 3000, y = 0, z = pt.z }
trigger.action.circleToAll(
    -1,
    9012,
    c_zero,
    3000,
    {0.0, 0.0, 1.0, 1.0}, -- BLUE positional
    {0.0, 0.0, 1.0, 0.5},
    1,
    false,
    "TEST3 y=0 offset positional"
)

trigger.action.outText(string.format(
    "[diag2] 3 circles fired\npt=(%.0f,%.0f) y=%.1f h=%.1f\nCheck F10 map for RED/GREEN/BLUE circles",
    pt.x, pt.z, pt.y, h), 30)

return string.format("OK pt=(%.0f,%.0f,%.0f) h=%.1f", pt.x, pt.y, pt.z, h)
