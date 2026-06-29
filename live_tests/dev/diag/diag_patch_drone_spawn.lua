-- diag_patch_drone_spawn.lua
-- Monkey-patch CTLDVehicleSpawner:_spawnGroundUnit to handle drone types.
-- Run this before diag_spawn_drone.lua when CTLD_Next.lua is an older build.

local _DRONE_TYPES = { ["MQ-9 Reaper"] = true, ["RQ-1A Predator"] = true }

CTLDVehicleSpawner._spawnGroundUnit = function(self, spawnData, position)
    if not spawnData then return end
    local cId   = spawnData.country or spawnData.coalitionId or 2
    local vt    = spawnData.vehicleType
    local gname = spawnData.groupName or (vt .. "_spawn_" .. timer.getAbsTime())
    local uname = spawnData.unitName  or vt

    local ok, err
    if _DRONE_TYPES[vt] then
        local alt   = ctld.gs("jtacDroneAltitude") or 4000
        local speed = 54
        local gid   = ctld.utils.getNextUniqId()
        local unitDef = {
            ["name"]          = gname,
            ["communication"] = true,
            ["frequency"]     = 124,
            ["groupId"]       = gid,
            ["task"]          = "Ground Nothing",
            ["visible"]       = false,
            ["hidden"]        = false,
            ["start_time"]    = 0,
            ["units"] = {
                [1] = {
                    ["type"]    = vt,
                    ["name"]    = uname,
                    ["x"]       = position.x,
                    ["y"]       = position.z,
                    ["heading"] = 0,
                    ["alt"]     = alt,
                    ["alt_type"] = "RADIO",
                    ["speed"]   = speed,
                    ["skill"]   = "Excellent",
                    ["unitId"]  = ctld.utils.getNextUniqId(),
                },
            },
            ["route"] = {
                ["points"] = {
                    [1] = {
                        ["alt"]                = alt,
                        ["action"]             = "Turning Point",
                        ["alt_type"]           = "RADIO",
                        ["speed"]              = speed,
                        ["type"]               = "Turning Point",
                        ["ETA"]                = 0,
                        ["ETA_locked"]         = true,
                        ["speed_locked"]       = true,
                        ["formation_template"] = "",
                        ["x"]                  = position.x,
                        ["y"]                  = position.z,
                        ["properties"]         = { ["addopt"] = {} },
                        ["task"] = {
                            ["id"]     = "ComboTask",
                            ["params"] = {
                                ["tasks"] = {
                                    [1] = {
                                        ["number"]  = 1, ["auto"] = true,
                                        ["id"]      = "WrappedAction", ["enabled"] = true,
                                        ["params"]  = {
                                            ["action"] = {
                                                ["id"]     = "EPLRS",
                                                ["params"] = { ["value"] = true, ["groupId"] = gid },
                                            },
                                        },
                                    },
                                    [2] = {
                                        ["number"]  = 2, ["auto"] = false,
                                        ["id"]      = "Orbit", ["enabled"] = true,
                                        ["params"]  = {
                                            ["altitude"] = alt,
                                            ["pattern"]  = "Circle",
                                            ["speed"]    = speed,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        }
        ok, err = pcall(coalition.addGroup, cId, Group.Category.AIRPLANE, unitDef)
        local errStr = type(err) == "table" and ctld.utils.p(err) or tostring(err)
        env.info("[PATCH_DRONE] addGroup AIRPLANE " .. vt .. " ok=" .. tostring(ok) .. " err=" .. errStr)
    else
        local unitDef = {
            name  = gname,
            task  = "Ground Nothing",
            units = {{
                type    = vt,
                name    = uname,
                x       = position.x,
                y       = position.z,
                heading = 0,
            }},
        }
        ok, err = pcall(coalition.addGroup, cId, Group.Category.GROUND, unitDef)
    end

    if not ok then
        ctld.utils.log("WARNING", "CTLDVehicleSpawner:_spawnGroundUnit - addGroup failed")
    end
end

env.info("[PATCH_DRONE] CTLDVehicleSpawner:_spawnGroundUnit patched")
return "patched"
