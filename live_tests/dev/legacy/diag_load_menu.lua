local LOG = (ctld and ctld.path or "") .. "CTLD.log"
local function log(msg)
    local f = io.open(LOG, "a")
    if f then f:write(msg .. "\n"); f:close() end
end

log("[diag] === CHECK LOAD MENU ===")

-- 1. Player
local units = coalition.getPlayers(coalition.side.BLUE) or {}
if #units == 0 then log("[diag] ABORT: no BLUE player"); return end
local playerUnit = units[1]
log("[diag] playerUnit=" .. playerUnit:getName() .. " type=" .. playerUnit:getTypeName())

-- 2. Config: unitActions pour ce type
local unitActions = ctld.gs("unitActions") or {}
local typeName = playerUnit:getTypeName()
local actions = unitActions[typeName]
log("[diag] unitActions[" .. typeName .. "] = " .. tostring(actions ~= nil))
if actions then
    for k, v in pairs(actions) do
        log("[diag]   actions." .. k .. " = " .. tostring(v))
    end
end

-- 3. PlayerObj isTransport
local pm = CTLDPlayerManager.getInstance()
local playerObj = pm:getPlayer(playerUnit:getName())
if playerObj then
    log("[diag] playerObj.isTransport=" .. tostring(playerObj.isTransport))
    log("[diag] playerObj.isAlive=" .. tostring(playerObj.isAlive))
else
    log("[diag] playerObj=nil (pas encore enregistré?)")
end

-- 4. inAir status
local inAir = ctld.utils.inAir(playerUnit)
log("[diag] inAir(transport)=" .. tostring(inAir))

-- 5. Crates within 50m
local mgr = CTLDCrateManager.getInstance()
local tPos = playerUnit:getPoint()
local near50 = mgr:getCratesInRange(tPos, 50)
log("[diag] getCratesInRange(50m)=" .. #near50)
for _, c in ipairs(near50) do
    local pos = (c.dcsStatic and c.dcsStatic:isExist()) and c.dcsStatic:getPoint() or c.position
    local d = ctld.utils.getDistance("diag", tPos, pos)
    log(string.format("[diag]   CRATE %s state=%s isOnGround=%s d=%.1fm",
        c.crateName, c.state, tostring(c:isOnGround()), d))
end

-- 6. Menu branch check
local mm = ctld.MenuManager:getInstance()
local menu = mm:getMenuByGroupId(playerObj and playerObj.groupId or -1)
log("[diag] menu for groupId=" .. (playerObj and playerObj.groupId or "nil") .. " : " .. tostring(menu ~= nil))

log("[diag] === END ===")
trigger.action.outText("[diag] Vérif menu Load — voir CTLD.log (Ctrl+Home)", 30)