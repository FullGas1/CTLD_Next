-- Dump all crates from CTLDCrateManager with their state
local ok, cm = pcall(CTLDCrateManager.getInstance)
if not ok or not cm then
    trigger.action.outText("[DUMP] CTLDCrateManager introuvable", 8)
    return "error"
end
local lines = {}
local count = 0
for _, crate in pairs(cm.crates or {}) do
    count = count + 1
    local staticAlive = crate.dcsStatic and crate.dcsStatic:isExist() and "YES" or "NO"
    lines[#lines+1] = string.format(
        "%s | state=%s | native=%s | static=%s | loadedBy=%s",
        crate.crateName,
        tostring(crate.state),
        tostring(crate.loadedByDCSNative),
        staticAlive,
        crate.loadedBy and crate.loadedBy:getName() or "nil")
end
if count == 0 then
    trigger.action.outText("[DUMP] Aucune crate dans CTLDCrateManager", 8)
    return "empty"
end
local msg = string.format("[DUMP] %d crate(s):\n", count) .. table.concat(lines, "\n")
trigger.action.outText(msg, 15)
env.info(msg)
return msg
