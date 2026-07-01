---@diagnostic disable
-- ============================================================
-- U-92 : CTLDi18n — ctld.i18n_audit() unknown language → nil + error string
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-92", "CTLDi18n — ctld.i18n_audit() unknown language → nil + error string")

local result, err = ctld.i18n_audit("zz")

-- result is nil
ctld_test.assertNil(result, "result is nil for unknown language")

-- err is a non-empty string
ctld_test.assert(type(err) == "string", "error is a string")
ctld_test.assert(#err > 0,             "error string is non-empty")
ctld_test.assert(err:find("zz") ~= nil, "error string mentions the unknown language code")

ctld_test.finish()
