-- diag_patch_jtac_drone.lua
-- Monkey-patch CTLDJTACManager with isDroneType + deployDroneCrate for testing.

local _DRONE_UNIT_TYPES = { ["MQ-9 Reaper"] = true, ["RQ-1A Predator"] = true }

CTLDJTACManager.isDroneType = function(self, unitType)
    return _DRONE_UNIT_TYPES[unitType] == true
end

CTLDJTACManager.deployDroneCrate = function(self, transport, position, descriptor, countryId)
    if ctld.gs("JTAC_dropEnabled") == false then
        env.info("[DRONE] JTAC_dropEnabled=false, skipped"); return false
    end
    local alt   = ctld.gs("jtacDroneAltitude") or 4000
    local speed = 54
    local gid   = ctld.utils.getNextUniqId()
    local uid   = ctld.utils.getNextUniqId()
    local gname = string.format("CTLD_JTAC_DRONE_%d", gid)
    local uname = gname .. "_1"
    local cId   = countryId or country.id.USA

    local unitDef = {
        ["name"]          = gname,   ["groupId"]       = gid,
        ["communication"] = true,    ["frequency"]     = 124,
        ["visible"]       = false,   ["hidden"]        = false,
        ["start_time"]    = 0,       ["task"]          = "Ground Nothing",
        ["x"]             = position.x, ["y"]          = position.z,
        ["units"] = {[1] = {
            ["type"]     = descriptor.unit, ["name"]    = uname,
            ["unitId"]   = uid,             ["x"]       = position.x,
            ["y"]        = position.z,      ["heading"] = 0,
            ["alt"]      = alt,             ["alt_type"] = "RADIO",
            ["speed"]    = speed,           ["skill"]   = "Excellent",
        }},
        ["route"] = { ["points"] = { [1] = {
            ["alt"] = alt, ["alt_type"] = "RADIO",
            ["action"] = "Turning Point", ["type"] = "Turning Point",
            ["speed"] = speed, ["ETA"] = 0, ["ETA_locked"] = true,
            ["speed_locked"] = true, ["formation_template"] = "",
            ["properties"] = { ["addopt"] = {} },
            ["x"] = position.x, ["y"] = position.z,
            ["task"] = { ["id"] = "ComboTask", ["params"] = { ["tasks"] = {
                [1] = { ["number"] = 1, ["auto"] = true, ["id"] = "WrappedAction",
                        ["enabled"] = true, ["params"] = { ["action"] = {
                            ["id"] = "EPLRS", ["params"] = { ["value"] = true, ["groupId"] = gid } } } },
                [2] = { ["number"] = 2, ["auto"] = false, ["id"] = "Orbit",
                        ["enabled"] = true, ["params"] = {
                            ["altitude"] = alt, ["pattern"] = "Circle", ["speed"] = speed } },
            }}},
        }}},
    }

    local ok, err = pcall(coalition.addGroup, cId, Group.Category.AIRPLANE, unitDef)
    if not ok then
        local s = type(err) == "table" and ctld.utils.p(err) or tostring(err)
        env.info("[DRONE] coalition.addGroup FAILED: " .. s)
        return false
    end
    env.info("[DRONE] spawned " .. gname .. " type=" .. descriptor.unit .. " alt=" .. alt)
    self:startLase(gname)
    return true
end

env.info("[PATCH_JTAC] isDroneType + deployDroneCrate injected")
return "patched"
