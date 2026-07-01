ctld.debug = true
local step = _G['_TFC_STEP']
local tmpl = nil
local troopMgr = CTLDTroopManager and CTLDTroopManager.getInstance()
if troopMgr then
    for _, t in ipairs(troopMgr._templates or {}) do
        if t.name == 'Test2JTAC' then tmpl = t; break end
    end
end
ctld.utils.log("INFO", "[tfc_state] _TFC_STEP=" .. tostring(step))
ctld.utils.log("INFO", "[tfc_state] Test2JTAC template=" .. tostring(tmpl ~= nil))
if tmpl then
    ctld.utils.log("INFO", "[tfc_state] tmpl.jtac=" .. tostring(tmpl.jtac) .. " hasJtac=" .. tostring(tmpl.hasJtac))
end
local jtacMgr = CTLDJTACManager and CTLDJTACManager.get()
if jtacMgr then
    local c = 0
    for _ in pairs(jtacMgr.jtacs or {}) do c = c + 1 end
    ctld.utils.log("INFO", "[tfc_state] JTAC entries=" .. c)
end
return "tfc_state done"