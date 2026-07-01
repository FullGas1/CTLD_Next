-- recette/enable_debug.lua — enable CTLD debug logging to recette/CTLD.log
-- Inject via Witchcraft at the start of each recette session.
local logDir = (ctld and ctld.path or "") .. "live_tests/"
local cfg = CTLDConfig.get()
cfg.settings["debug"]        = true
cfg.settings["ctldLogPath"]  = logDir
ctld.utils.initLog()
ctld.logInfo("=== DEBUG MODE ENABLED — log: %sCTLD.log ===", logDir)
return "Debug enabled — CTLD.log → " .. logDir .. "CTLD.log"
