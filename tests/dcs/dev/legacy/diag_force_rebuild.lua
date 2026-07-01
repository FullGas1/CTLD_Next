local LOG = (ctld and ctld.path or "") .. "CTLD.log"
local function log(msg)
    local f = io.open(LOG, "a")
    if f then f:write(msg .. "\n"); f:close() end
end

log("[diag] === FORCE REBUILD LOAD MENU ===")

local units = coalition.getPlayers(coalition.side.BLUE) or {}
if #units == 0 then log("[diag] ABORT: no BLUE player"); return end
local playerUnit = units[1]
local pm = CTLDPlayerManager.getInstance()
local playerObj = pm:getPlayer(playerUnit:getName())
if not playerObj then log("[diag] ABORT: playerObj nil"); return end

log("[diag] playerObj.unitName=" .. playerObj.unitName)
log("[diag] playerObj.groupId=" .. tostring(playerObj.groupId))

local mm = ctld.MenuManager:getInstance()
local menu = mm:getMenuByGroupId(playerObj.groupId)
log("[diag] menu=" .. tostring(menu))

-- Test: forcer un rebuild complet du menu Load Crate
log("[diag] FORCE REBUILD...")
local mgr = CTLDCrateManager.getInstance()

-- clear
local root = ctld.tr("CTLD")
local cratesSub = ctld.tr("Crate Commands")
local loadSub = ctld.tr("Load Crate")
log("[diag] clearBranch path: {" .. root .. "," .. cratesSub .. "," .. loadSub .. "}")
menu:clearBranch({ root, cratesSub, loadSub })

-- Vérifier ce qu'il reste après clear
log("[diag] après clear - vérifier children de loadSub:")

-- Respawn crates manually pour test
local transport = Unit.getByName(playerObj.unitName)
local tPos = transport:getPoint()
local near50 = mgr:getCratesInRange(tPos, 50)
log("[diag] near50 count=" .. #near50)

if #near50 == 0 then
    log("[diag] AUCUNE crate trouvée — getCratesInRange renvoie vide alors que les crates existent dans le registry")
    -- Compter manuellement
    local total = 0
    for cn, c in pairs(mgr.crates) do
        total = total + 1
        local pos = (c.dcsStatic and c.dcsStatic:isExist()) and c.dcsStatic:getPoint() or c.position
        local d = ctld.utils.getDistance("diag", tPos, pos)
        log(string.format("[diag]   crate[%d] %s state=%s dcsStatic:isExist=%s d=%.1fm",
            total, cn, c.state,
            tostring(c.dcsStatic and c.dcsStatic:isExist()),
            d))
    end
    log("[diag] total crates in registry=" .. total)
else
    -- Reconstruire le menu manuellement
    local byType = {}
    for _, c in ipairs(near50) do
        local desc = c.descriptor and c.descriptor.desc or "Unknown"
        if not byType[desc] then
            byType[desc] = { count = 0, descriptor = c.descriptor }
        end
        byType[desc].count = byType[desc].count + 1
    end

    if not next(byType) then
        menu:addCommand({ root, cratesSub, loadSub },
            ctld.tr("No crates within 50m"), function() end, {})
        log("[diag] ajouté: 'No crates within 50m'")
    else
        for desc, data in pairs(byType) do
            local label = string.format("%s (%d)", desc, data.count)
            menu:addCommand({ root, cratesSub, loadSub }, label,
                function(arg) log("[diag] LOAD clicked: " .. arg.crateDesc) end,
                { crateDesc = desc, unitName = playerObj.unitName })
            log("[diag] ajouté: '" .. label .. "'")
        end
    end
end

menu:refresh()
log("[diag] menu:refresh() appelé")
log("[diag] === FIN ===")
trigger.action.outText("Diagnostic Menu Load terminé — voir CTLD.log", 30)