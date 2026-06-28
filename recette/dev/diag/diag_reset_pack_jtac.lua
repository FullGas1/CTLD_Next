_G["_PACK_JTAC_STEP"] = 1
local g1 = Group.getByName("SCN_PACK_JTAC_HMR");    if g1 then g1:destroy() end
local g2 = Group.getByName("SCN_PACK_JTAC_TARGET");  if g2 then g2:destroy() end
local jm = CTLDJTACManager.get()
if jm.jtacs and jm.jtacs["SCN_PACK_JTAC_HMR"] then
    jm:stopLase("SCN_PACK_JTAC_HMR")
    jm.jtacs["SCN_PACK_JTAC_HMR"] = nil
end
return "RESET OK step=1"
