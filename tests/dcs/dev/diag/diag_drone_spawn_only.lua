-- diag_drone_spawn_only.lua — spawn MQ-9 as AIRPLANE WITHOUT startLase
-- To isolate: is the crash from addGroup or from _autoLaseLoop?

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"
local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then return "aircraft not found" end

local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("drone_only", transport, true)
local ox  = pt.x + math.cos(hdg) * 400
local oz  = pt.z + math.sin(hdg) * 400

local alt   = 4000
local speed = 54
local gid   = ctld.utils.getNextUniqId()
local uid   = ctld.utils.getNextUniqId()
local gname = "CTLD_DRONE_NOJTAC_" .. gid

local unitDef = {
    ["name"] = gname, ["groupId"] = gid,
    ["communication"] = true, ["frequency"] = 124,
    ["visible"] = false, ["hidden"] = false, ["start_time"] = 0,
    ["task"] = "Ground Nothing",
    ["x"] = ox, ["y"] = oz,
    ["units"] = {[1] = {
        ["type"] = "MQ-9 Reaper", ["name"] = gname .. "_1",
        ["unitId"] = uid, ["x"] = ox, ["y"] = oz,
        ["heading"] = 0, ["alt"] = alt, ["alt_type"] = "RADIO",
        ["speed"] = speed, ["skill"] = "Excellent",
    }},
    ["route"] = { ["points"] = { [1] = {
        ["alt"] = alt, ["alt_type"] = "RADIO",
        ["action"] = "Turning Point", ["type"] = "Turning Point",
        ["speed"] = speed, ["ETA"] = 0, ["ETA_locked"] = true,
        ["speed_locked"] = true, ["formation_template"] = "",
        ["properties"] = { ["addopt"] = {} },
        ["x"] = ox, ["y"] = oz,
        ["task"] = { ["id"] = "ComboTask", ["params"] = { ["tasks"] = {
            [1] = { ["number"] = 1, ["auto"] = true, ["id"] = "WrappedAction",
                    ["enabled"] = true, ["params"] = { ["action"] = {
                        ["id"] = "EPLRS",
                        ["params"] = { ["value"] = true, ["groupId"] = gid } } } },
            [2] = { ["number"] = 2, ["auto"] = false, ["id"] = "Orbit",
                    ["enabled"] = true, ["params"] = {
                        ["altitude"] = alt, ["pattern"] = "Circle", ["speed"] = speed } },
        }}},
    }}},
}

local ok, err = pcall(coalition.addGroup, country.id.USA, Group.Category.AIRPLANE, unitDef)
if not ok then
    local s = type(err) == "table" and ctld.utils.p(err) or tostring(err)
    return "FAILED: " .. s
end

-- Check immediately
local g = Group.getByName(gname)
if not g then return "addGroup ok but group not found: " .. gname end
local cat = g:getCategory()
local u1  = g:getUnit(1)
local alt2 = u1 and u1:getPoint().y or -1
return string.format("OK: %s cat=%d alt=%.0f", gname, cat, alt2)
