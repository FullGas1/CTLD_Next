---@diagnostic disable
-- scenarios/diag_crate_load.lua
-- Écriture directe dans CTLD.log via io (contexte DCS Witchcraft)

local LOG = (ctld and ctld.path or "") .. "CTLD.log"
local function log(msg)
    local f = io.open(LOG, "a")
    if f then f:write(msg .. "\n"); f:close() end
end

log("[diag] === START ===")

local playerUnit = nil
do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    log("[diag] BLUE players: " .. #units)
    if #units > 0 then playerUnit = units[1] end
end
if not playerUnit or not playerUnit:isExist() then
    log("[diag] ABORT: no BLUE player")
    return
end

log("[diag] player=" .. playerUnit:getName())
local mgr = CTLDCrateManager.getInstance()
log("[diag] mgr.crates count=" .. (mgr and #mgr.crates or -1))

local tPos = playerUnit:getPoint()
log(string.format("[diag] tPos={%.1f,%.1f,%.1f}", tPos.x, tPos.y, tPos.z))

local near50 = mgr:getCratesInRange(tPos, 50)
local near200 = mgr:getCratesInRange(tPos, 200)
log(string.format("[diag] near50=%d near200=%d", #near50, #near200))

for _, c in ipairs(near200) do
    local pos = (c.dcsStatic and c.dcsStatic:isExist()) and c.dcsStatic:getPoint() or c.position
    local d = ctld.utils.getDistance("diag", tPos, pos)
    log(string.format(
        "[diag] CRATE cr=%s dsc=%s dcsStatic:isExist=%s d=%.1fm spawnPos={%.1f,%.1f,%.1f}",
        c.crateName,
        c.descriptor and c.descriptor.desc or "nil",
        tostring(c.dcsStatic and c.dcsStatic:isExist()),
        d,
        c.position.x or 0, c.position.y or 0, c.position.z or 0))
end

log("[diag] === END ===")
trigger.action.outText(string.format("[diag] crates 50m=%d / 200m=%d (voir CTLD.log)", #near50, #near200), 30)