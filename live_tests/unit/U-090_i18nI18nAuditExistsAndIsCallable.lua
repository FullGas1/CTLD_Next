---@diagnostic disable
-- ============================================================
-- U-90 : CTLDi18n — ctld.i18n_audit() exists and is callable
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-90", "CTLDi18n — ctld.i18n_audit() exists and is callable")

-- Function exists
ctld_test.assert(type(ctld.i18n_audit) == "function", "ctld.i18n_audit is a function")

-- Function exists
ctld_test.assert(type(ctld.i18n_auditAll) == "function", "ctld.i18n_auditAll is a function")

-- Callable without error
local ok, result = pcall(ctld.i18n_audit, "en")
ctld_test.assert(ok, "ctld.i18n_audit('en') does not throw an error")

-- Returns a table when called with valid language
ctld_test.assert(type(result) == "table", "ctld.i18n_audit('en') returns a table")

ctld_test.finish()
