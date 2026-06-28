-- Inspect CTLDCrateAssemblyManager internals to find templates field name
local aaMgr = CTLDCrateAssemblyManager.getInstance()
local keys = {}
for k, v in pairs(aaMgr) do
    keys[#keys+1] = string.format("  [%s] = %s", tostring(k), type(v))
end
env.info("[AA_KEYS]\n" .. table.concat(keys, "\n"))
