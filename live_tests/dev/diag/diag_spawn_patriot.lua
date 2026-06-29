-- diag_spawn_patriot.lua
-- Spawn a complete Patriot AA system 200m ahead of the player,
-- registered in CTLDCrateAssemblyManager so CTLD tracks it
-- (repair/rearm menus will work).
-- Uses _spawnGroup and _buildSpawnArrays via a mock heli + fake parts.

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"
local TEMPLATE_NAME = "Patriot AA System"

local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then
    env.info("[SPAWN_PATRIOT] aircraft not found: " .. AIRCRAFT_NAME)
    return
end

-- Find the Patriot template
local template = nil
for _, t in ipairs(CTLDCrateAssemblyManager.TEMPLATES) do
    if t.name == TEMPLATE_NAME then template = t; break end
end
if not template then
    env.info("[SPAWN_PATRIOT] template not found: " .. TEMPLATE_NAME)
    return
end

local aaMgr = CTLDCrateAssemblyManager.getInstance()

-- Build fake systemParts (all NoCrate so assembly skips crate checks)
-- Each part gets found=required=1 so _buildSpawnArrays spawns exactly
-- the configured amount.
local systemParts = {}
for _, part in ipairs(template.parts) do
    systemParts[part.name] = {
        found    = 1,
        required = 1,
        NoCrate  = true,
        amount   = part.amount,
        desc     = part.desc,
        crates   = {},
    }
end

-- Compute origin 200m ahead (override _computeOrigin's 100m)
local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("spawn_patriot", transport, true)
local origin = {
    x = pt.x + math.cos(hdg) * 200,
    y = land.getHeight({ x = pt.x + math.cos(hdg) * 200,
                         y = pt.z + math.sin(hdg) * 200 }),
    z = pt.z + math.sin(hdg) * 200,
}

-- Build spawn arrays using existing logic
local positions, types, headings = aaMgr:_buildSpawnArrays(template, systemParts, origin, transport)

-- Spawn the group
local group = aaMgr:_spawnGroup(transport, positions, types, headings)
if not group then
    env.info("[SPAWN_PATRIOT] _spawnGroup failed")
    return
end

-- Register in _completeSystems so CTLD knows about it
aaMgr._completeSystems[group:getName()] = {
    details  = aaMgr:_getDetails(group, template),
    template = template,
}

env.info(string.format("[SPAWN_PATRIOT] spawned %s → group=%s  units=%d  origin=(%.0f,%.1f,%.0f)",
    TEMPLATE_NAME, group:getName(), #positions, origin.x, origin.y, origin.z))
