---@diagnostic disable
-- tests/ci/helpers/init.lua
-- Loaded by busted before every spec (configured in .busted helper field).
-- 1. Injects DCS API stubs into the global environment.
-- 2. Loads all CTLD src/ modules (idempotent via _CTLD_LOADED guard in loader.lua).
-- ============================================================

-- Resolve repo root from this file's path.
-- Absolute path  →  capture everything before "tests/ci/helpers/init.lua"
-- Relative path  →  busted was invoked from the repo root, so root = ""
local _thisFile = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]helpers[\\/]init%.lua$")
if not _thisFile then
  -- Relative source (e.g. "@tests/ci/helpers/init.lua") — cwd IS the repo root
  _thisFile = ""
end

-- Load DCS stubs first (globals must exist before src/ modules load)
dofile(_thisFile .. "tests/ci/helpers/dcs_stubs.lua")

-- Load all CTLD modules
dofile(_thisFile .. "tests/ci/helpers/loader.lua")
