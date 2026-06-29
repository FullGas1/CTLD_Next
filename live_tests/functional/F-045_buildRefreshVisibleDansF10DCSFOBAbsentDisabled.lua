---@diagnostic disable
-- F-45 : Build + refresh() visible dans F10 DCS — FOB absent (disabled)
-- REQUIRES: DCS mission running, BLUE player in slot
-- NOTE: loads sources WITHOUT setup.lua to preserve real DCS missionCommands API

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC.."lib/class.lua")
dofile(SRC.."CTLD_config.lua")
ctld = ctld or {}
ctld.tr = function(k) return k end
CTLDConfig.get():load()
if not ctld.gs then
    function ctld.gs(k) return CTLDConfig.get().settings[k] end
end
ctld.logInfo    = function(fmt, ...) env.info(string.format("[INFO] "  .. tostring(fmt), ...)) end
ctld.logWarning = function(fmt, ...) env.info(string.format("[WARN] "  .. tostring(fmt), ...)) end
ctld.logError   = function(fmt, ...) env.info(string.format("[ERROR] " .. tostring(fmt), ...)) end
dofile(SRC.."CTLD_utils.lua")
dofile(SRC.."CTLD_i18n.lua")
dofile(SRC.."CTLD_i18n_en.lua")
dofile(SRC.."CTLD_menu.lua")
dofile(SRC.."lib/CTLD_objectRegistry.lua")
dofile(SRC.."lib/CTLDParachuteEffect.lua")
dofile(SRC.."CTLD_core.lua")
dofile(SRC.."CTLD_zone.lua")
dofile(SRC.."CTLD_troop.lua")
dofile(SRC.."CTLD_vehicle.lua")
dofile(SRC.."CTLD_crate.lua")
dofile(SRC.."CTLD_beacon.lua")
dofile(SRC.."CTLD_recon.lua")
dofile(SRC.."CTLD_jtac.lua")
dofile(SRC.."CTLD_player.lua")

-- Reset singletons (clean state)
CTLDPlayerManager._instance  = nil
ctld.MenuManager._instance   = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDZoneManager._instance    = nil
CTLDTroopManager._instance   = nil
CTLDVehicleSpawner._instance = nil
_cmInstance                  = nil
CTLDBeaconManager._instance  = nil
CTLDReconManager._instance   = nil
CTLDJTACManager._instance    = nil

local players = coalition.getPlayers(coalition.side.BLUE) or {}
local unit = players[1]
if not unit then
    trigger.action.outText("F-45 SKIP: no BLUE player found", 10)
    env.info("[F-45] SKIP: no BLUE player")
    return
end

local groupId = unit:getGroup():getID()
env.info("[F-45] unit=" .. unit:getName() .. " groupId=" .. tostring(groupId))

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(groupId)
menu:addSubMenu({}, "CTLD Commands", { order=100 })
menu:addSubMenu({"CTLD Commands"}, "Troops",        { order=10 })
menu:addSubMenu({"CTLD Commands"}, "Crates",        { order=20 })
menu:addSubMenu({"CTLD Commands"}, "Pack Vehicles", { order=30 })
menu:addSubMenu({"CTLD Commands"}, "FOB",           { order=40, enabled=false })
menu:refresh()

trigger.action.outText(
    "F-45 VISUAL CHECK:\nPress * — F10 menu must show:\n  Troops / Crates / Pack Vehicles\n  FOB must NOT appear.", 40)
env.info("[F-45] refresh() done. Awaiting visual confirmation.")
