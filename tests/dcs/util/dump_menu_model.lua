---@diagnostic disable
-- dump_menu_model.lua v5 — outText screen only

local pm = CTLDPlayerManager.getInstance()
local mm = ctld.MenuManager:getInstance()

local function out(msg)
    trigger.action.outText(msg, 30)
end

local count = 0
for _ in pairs(pm._players) do count = count + 1 end
out("[DUMP] players=" .. count)

local playerObj
for _, p in pairs(pm._players) do playerObj = p; break end

if not playerObj then
    out("[DUMP] no player found in _players")
    return Witchcraft
end

out("[DUMP] unit=" .. playerObj.unitName .. " gid=" .. playerObj.groupId)

local menu = mm:getMenuByGroupId(playerObj.groupId)
if not menu then out("[DUMP] no menu"); return Witchcraft end

out("[DUMP] root children: " .. #(menu.children or {}))

-- Trouve CTLD
local ctldNode
for _, c in ipairs(menu.children or {}) do
    if c.name == ctld.tr("CTLD") then ctldNode = c end
end
if not ctldNode then out("[DUMP] no CTLD node, tr='" .. ctld.tr("CTLD") .. "'"); return Witchcraft end

local function sorted(children)
    local t = {}
    for _, c in ipairs(children or {}) do t[#t+1] = c end
    table.sort(t, function(a,b) return (a.order or 1e9) < (b.order or 1e9) end)
    return t
end

-- ROOT level
local rootLines = {"=== CTLD ROOT ==="}
local fIdx = 1
local crateNode, smokeNode
for _, child in ipairs(sorted(ctldNode.children)) do
    local en = (child.enabled ~= false)
    local fStr = en and ("F"..fIdx) or "--"
    rootLines[#rootLines+1] = fStr .. " " .. tostring(child.name) .. " [" .. (en and "ON" or "OFF") .. "] ord=" .. tostring(child.order or "inf")
    if en then fIdx = fIdx + 1 end
    if child.name == ctld.tr("Crate Commands") then crateNode = child end
    if child.name == ctld.tr("Smoke") then smokeNode = child end
end
out(table.concat(rootLines, "\n"))

-- CRATE COMMANDS
if crateNode then
    local lines = {"=== Crate Commands ==="}
    local fC = 1
    for _, cc in ipairs(sorted(crateNode.children)) do
        local enC = (cc.enabled ~= false)
        local fC2 = enC and ("F"..fC) or "--"
        lines[#lines+1] = fC2 .. " " .. tostring(cc.name) .. " [" .. (enC and "ON" or "OFF") .. "] ord=" .. tostring(cc.order or "inf")
        if enC then fC = fC + 1 end
    end
    out(table.concat(lines, "\n"))
end

-- SMOKE
if smokeNode then
    local lines = {"=== Smoke ==="}
    local fS = 1
    for _, sc in ipairs(sorted(smokeNode.children)) do
        local enS = (sc.enabled ~= false)
        lines[#lines+1] = "F"..fS .. " " .. tostring(sc.name) .. " [" .. (enS and "ON" or "OFF") .. "]"
        if enS then fS = fS + 1 end
    end
    out(table.concat(lines, "\n"))
end

return Witchcraft
