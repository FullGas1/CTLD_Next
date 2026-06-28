-- diag_spawn_shortrange.lua
-- BLUE short range (Roland ADS) at 12 o'clock, 200m
-- RED  short range (Osa 9A33)   at  3 o'clock, 200m

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"

local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then
    env.info("[SPAWN_SR] aircraft not found"); return
end

local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("spawn_sr", transport, true)

local function _spawnUnit(typeName, cId, ox, oz, label)
    local uid = ctld.utils.getNextUniqId()
    local gdata = {
        ["visible"] = false, ["task"] = "Ground Nothing",
        ["route"] = { ["points"] = {} },
        ["groupId"] = uid, ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["x"] = ox, ["y"] = oz, ["type"] = typeName,
                ["unitId"] = ctld.utils.getNextUniqId(),
                ["heading"] = hdg, ["playerCanDrive"] = false,
                ["skill"] = "Excellent",
                ["name"] = "CTLD_SR_" .. label .. "_" .. uid,
            },
        },
        ["y"] = oz, ["x"] = ox,
        ["name"] = "CTLD_SR_GRP_" .. label .. "_" .. uid,
        ["start_time"] = 0,
    }
    local coa = (cId == country.id.RUSSIA)
        and coalition.side.RED or coalition.side.BLUE
    local ok = pcall(function()
        coalition.addGroup(cId, Group.Category.GROUND, gdata)
    end)
    if ok then
        env.info(string.format("[SPAWN_SR] %s → %s at (%.0f,%.0f)", label, typeName, ox, oz))
    else
        env.info("[SPAWN_SR] FAILED: " .. label .. " / " .. typeName)
    end
end

-- 12 o'clock = heading (BLUE Roland ADS)
local b_ox = pt.x + math.cos(hdg)            * 200
local b_oz = pt.z + math.sin(hdg)            * 200
_spawnUnit("Roland ADS", country.id.USA, b_ox, b_oz, "BLUE_12h")

-- 3 o'clock = heading + 90° (RED Osa 9A33)
local hdg3 = hdg + math.pi / 2
local r_ox = pt.x + math.cos(hdg3) * 200
local r_oz = pt.z + math.sin(hdg3) * 200
_spawnUnit("Osa 9A33 ln", country.id.RUSSIA, r_ox, r_oz, "RED_3h")
