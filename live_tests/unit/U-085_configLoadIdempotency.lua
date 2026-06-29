---@diagnostic disable
-- ============================================================
-- U-85 : CTLDConfig — load() idempotency
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-85", "CTLDConfig load() idempotency")

local cfg = CTLDConfig.get()

-- Mutate a setting before calling load() a second time
cfg.settings["numberOfTroops"] = 77

-- Second load() must return early (isLoaded == true)
local ok, msg = cfg:load()
ctld_test.assertEqual(ok,  true,                              "2nd load() returns true")
ctld_test.assert(type(msg) == "string",                       "2nd load() returns a message string")
ctld_test.assert(msg:find("already loaded") ~= nil,           "message contains 'already loaded'")

-- Setting must NOT have been reset to default (still 77)
ctld_test.assertEqual(cfg.settings["numberOfTroops"], 77,     "mutation preserved — defaults NOT reloaded")

-- Restore
cfg.settings["numberOfTroops"] = 10

ctld_test.finish()
