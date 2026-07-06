---@diagnostic disable
-- tests/ci/helpers/loader.lua
-- Loads all src/ modules in dependency order (mirrors listToMerge.txt).
-- Call require("tests.ci.helpers.loader") once per spec file (idempotent via _CTLD_LOADED guard).
-- ============================================================

if _CTLD_LOADED then return end
_CTLD_LOADED = true

-- Resolve repo root: three levels up from this file (tests/ci/helpers/loader.lua).
-- Relative source (busted invoked from repo root) → root = ""
local _src = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]helpers[\\/]loader%.lua$")
if not _src then _src = "" end
local SRC = _src .. "src/"

-- ── Silence the log file (write to OS temp dir) ──
ctld = ctld or {}
ctld.debug  = false
ctldLogPath = (os.getenv("TEMP") or os.getenv("TMP") or "/tmp") .. "/"

-- ── Core foundations ──────────────────────────────────────────
dofile(SRC .. "core/class.lua")
-- CTLDCrateAssemblyManager must exist before CTLDConfig:load() runs
-- (load() sets CTLDCrateAssemblyManager.TEMPLATES). Only needs class().
dofile(SRC .. "CTLD_aasystem.lua")
dofile(SRC .. "CTLD_config.lua")

-- Minimal i18n stub so ctld.tr() is available before CTLD_i18n loads
ctld.tr = ctld.tr or function(key, default) return default or key end
CTLDConfig.get():load()

dofile(SRC .. "CTLD_utils.lua")
dofile(SRC .. "CTLD_i18n.lua")
dofile(SRC .. "CTLD_i18n_en.lua")
dofile(SRC .. "CTLD_menu.lua")
dofile(SRC .. "core/CTLD_objectRegistry.lua")
dofile(SRC .. "core/CTLDParachuteEffect.lua")
dofile(SRC .. "core/CTLD_modValidator.lua")

-- ── Business domain managers ──────────────────────────────────
dofile(SRC .. "CTLD_sceneManager.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_troop.lua")
dofile(SRC .. "CTLD_crate.lua")
dofile(SRC .. "CTLD_vehicle.lua")
dofile(SRC .. "CTLD_fob.lua")
-- CTLD_aasystem.lua already loaded above (before CTLDConfig:load)
dofile(SRC .. "CTLD_beacon.lua")
dofile(SRC .. "CTLD_recon.lua")
dofile(SRC .. "CTLD_jtac.lua")
dofile(SRC .. "CTLD_player.lua")

-- ── Orchestrator ──────────────────────────────────────────────
dofile(SRC .. "CTLD_core.lua")
