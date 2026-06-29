---@diagnostic disable
-- CTLD Dev Loader
-- Auto-generated from build/listToMerge.txt - DO NOT EDIT MANUALLY
-- Regenerate with: powershell -ExecutionPolicy Bypass -File tools/build/generate_loader.ps1
--
-- HOW TO USE:
--   1. Set CTLD_SOURCE_PATH to the absolute path of your src/ directory.
--   2. Use forward slashes. End with a trailing slash.
--   3. In your DCS mission trigger: dofile('absolute/path/to/CTLD_loader.lua')

local CTLD_SOURCE_PATH = "C:/replace/with/your/absolute/path/to/src/"  -- CONFIGURE THIS

-- Core foundations (no business state)
dofile(CTLD_SOURCE_PATH .. "lib/class.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_config.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_i18n.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_i18n_en.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_i18n_fr.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_i18n_es.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_i18n_ko.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_utils.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_menu.lua")
dofile(CTLD_SOURCE_PATH .. "lib/CTLD_objectRegistry.lua")
dofile(CTLD_SOURCE_PATH .. "lib/CTLDParachuteEffect.lua")
-- Business domain managers
dofile(CTLD_SOURCE_PATH .. "CTLD_sceneManager.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_zone.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_troop.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_crate.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_vehicle.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_fob.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_aasystem.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_beacon.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_recon.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_jtac.lua")
dofile(CTLD_SOURCE_PATH .. "CTLD_player.lua")
-- Orchestrator
dofile(CTLD_SOURCE_PATH .. "CTLD_core.lua")
-- Scene data (after CTLDSceneManager registry is ready)
dofile(CTLD_SOURCE_PATH .. "scenes/CTLD_farpScene.lua")
dofile(CTLD_SOURCE_PATH .. "scenes/CTLD_fobScene.lua")
dofile(CTLD_SOURCE_PATH .. "scenes/CTLD_mineFieldScene.lua")
-- Legacy API compatibility (after all managers)
dofile(CTLD_SOURCE_PATH .. "compat/legacy_api.lua")
-- User configuration (always last)
dofile(CTLD_SOURCE_PATH .. "CTLD_userConfig.lua")
