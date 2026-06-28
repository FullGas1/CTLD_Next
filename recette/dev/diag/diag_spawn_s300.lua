-- diag_spawn_s300.lua
-- Spawn a complete S-300 AA system (RED) 200m ahead of the player.
-- Registered in CTLDCrateAssemblyManager for CTLD tracking.

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"
local TEMPLATE_NAME = "S-300 AA System"

local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then
    env.info("[SPAWN_S300] aircraft not found: " .. AIRCRAFT_NAME)
    return
end

local template = nil
for _, t in ipairs(CTLDCrateAssemblyManager.TEMPLATES) do
    if t.name == TEMPLATE_NAME then template = t; break end
end
if not template then
    env.info("[SPAWN_S300] template not found: " .. TEMPLATE_NAME)
    return
end

local aaMgr = CTLDCrateAssemblyManager.getInstance()

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

local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("spawn_s300", transport, true)
local ox  = pt.x + math.cos(hdg) * 200
local oz  = pt.z + math.sin(hdg) * 200
local origin = { x = ox, y = land.getHeight({ x = ox, y = oz }), z = oz }

local positions, types, headings = aaMgr:_buildSpawnArrays(template, systemParts, origin, transport)

-- Force RED coalition: temporarily override transport coalition for _spawnGroup
-- _spawnGroup uses heli:getCoalition() → we spawn a RED proxy group directly
local cId = country.id.RUSSIA
local uid = ctld.utils.getNextUniqId()
local gdata = {
    ["visible"]    = false,
    ["task"]       = "Ground Nothing",
    ["route"]      = { ["points"] = {} },
    ["groupId"]    = uid,
    ["hidden"]     = false,
    ["units"]      = {},
    ["y"]          = positions[1] and positions[1].z or origin.z,
    ["x"]          = positions[1] and positions[1].x or origin.x,
    ["name"]       = "CTLD_S300_RED_" .. uid,
    ["start_time"] = 0,
}
for i, pos in ipairs(positions) do
    local uId = ctld.utils.getNextUniqId()
    gdata["units"][i] = {
        ["x"]              = pos.x,
        ["y"]              = pos.z,
        ["type"]           = types[i],
        ["unitId"]         = uId,
        ["heading"]        = headings[i] or 0,
        ["playerCanDrive"] = false,
        ["skill"]          = "Excellent",
        ["name"]           = "CTLD_S300_RED_" .. uid .. "_" .. i,
    }
end

local ok = pcall(function() coalition.addGroup(cId, Group.Category.GROUND, gdata) end)
if not ok then
    env.info("[SPAWN_S300] coalition.addGroup failed")
    return
end

local group = Group.getByName(gdata["name"])
if not group then
    env.info("[SPAWN_S300] group not found after spawn")
    return
end

aaMgr._completeSystems[group:getName()] = {
    details  = aaMgr:_getDetails(group, template),
    template = template,
}

env.info(string.format("[SPAWN_S300] spawned %s → group=%s  units=%d  origin=(%.0f,%.1f,%.0f)",
    TEMPLATE_NAME, group:getName(), #positions, origin.x, origin.y, origin.z))
