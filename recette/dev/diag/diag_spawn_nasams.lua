-- diag_spawn_nasams.lua
-- Spawn a complete NASAMS AA system (BLUE) 200m ahead of the player.

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"
local TEMPLATE_NAME = "NASAMS AA System"

local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then
    env.info("[SPAWN_NASAMS] aircraft not found: " .. AIRCRAFT_NAME); return
end

local template = nil
for _, t in ipairs(CTLDCrateAssemblyManager.TEMPLATES) do
    if t.name == TEMPLATE_NAME then template = t; break end
end
if not template then
    env.info("[SPAWN_NASAMS] template not found"); return
end

local aaMgr = CTLDCrateAssemblyManager.getInstance()

local systemParts = {}
for _, part in ipairs(template.parts) do
    systemParts[part.name] = {
        found = 1, required = 1, NoCrate = true,
        amount = part.amount, desc = part.desc, crates = {},
    }
end

local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("spawn_nasams", transport, true)
local ox  = pt.x + math.cos(hdg) * 200
local oz  = pt.z + math.sin(hdg) * 200
local origin = { x = ox, y = land.getHeight({ x = ox, y = oz }), z = oz }

local positions, types, headings = aaMgr:_buildSpawnArrays(template, systemParts, origin, transport)
local group = aaMgr:_spawnGroup(transport, positions, types, headings)
if not group then env.info("[SPAWN_NASAMS] _spawnGroup failed"); return end

aaMgr._completeSystems[group:getName()] = {
    details  = aaMgr:_getDetails(group, template),
    template = template,
}

env.info(string.format("[SPAWN_NASAMS] spawned %s → group=%s  units=%d  origin=(%.0f,%.1f,%.0f)",
    TEMPLATE_NAME, group:getName(), #positions, origin.x, origin.y, origin.z))
