---@diagnostic disable
-- enable_debug.lua — active debug CTLD pour la session courante
local cfg = CTLDConfig.get()
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true
cfg.settings["debugScreenLogDuration"] = 10
return "[DEBUG] enabled"
