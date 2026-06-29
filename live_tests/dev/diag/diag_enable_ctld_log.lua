-- diag_enable_ctld_log.lua
-- Enables debug logging to recette/CTLD.log at runtime (no rebuild needed)
CTLDConfig.get().settings["debug"]       = true
CTLDConfig.get().settings["ctldLogPath"] = (ctld and ctld.path or "") .. "live_tests/"
ctld.utils.initLog()
ctld.utils.log("INFO", "[diag] CTLD.log opened — debug logging active")
trigger.action.outText("[debug] CTLD.log ouvert dans recette/", 8)
return "CTLD.log enabled"
