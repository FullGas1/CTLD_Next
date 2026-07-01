---@diagnostic disable
-- diag_farp_fg_probe.lua
-- Diagnostic probe manuel pour Farp_FG_Petit_Helipad
-- Vérifie chaque étape de _probeHeliport pour identifier le point d'échec.

local typeName  = "Farp_FG_Petit_Helipad"
local shapeName = "Farp_FG_Petit_Helipad.edm"
local probeName = "DIAG_FG_HP_001"

-- Récupère une position de référence depuis le premier groupe trouvé
local refX, refZ = 0, 0
for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
    local ok, groups = pcall(coalition.getGroups, coa)
    if ok and groups and #groups > 0 then
        local units = groups[1]:getUnits()
        if units and #units > 0 then
            local pt = units[1]:getPoint()
            refX, refZ = pt.x, pt.z
            break
        end
    end
end

local staticData = {
    name          = probeName,
    type          = typeName,
    category      = "Heliports",
    x             = refX + 10,
    y             = refZ + 800000,   -- off-map +800 km nord (même formule que _probeHeliport)
    heading       = 0,
    start_time    = 0,
    shape_name    = shapeName,
    transportable = { randomTransportable = false },
    dead          = false,
    heliport_frequency   = "127.5",
    heliport_callsign_id = 1,
    heliport_modulation  = 0,
}

-- Étape 1 : addStaticObject
local ok1, obj = pcall(coalition.addStaticObject, country.id.USA, staticData)
local step1 = "addStaticObject → ok=" .. tostring(ok1) .. "  obj=" .. tostring(obj ~= nil)
if not ok1 then step1 = step1 .. "  ERR=" .. tostring(obj) end

-- Étape 2 : StaticObject.getByName
local so   = StaticObject.getByName(probeName)
local step2 = "StaticObject.getByName → " .. tostring(so ~= nil)

-- Étape 3 : Airbase.getByName
local ab   = Airbase.getByName(probeName)
local step3 = "Airbase.getByName → " .. tostring(ab ~= nil)

-- Étape 4 : getDesc().life via StaticObject
local step4 = "getDesc().life (StaticObject) → N/A"
if so then
    local okD, d = pcall(function() return so:getDesc() end)
    if okD and type(d) == "table" then
        step4 = "getDesc().life (StaticObject) → " .. tostring(d.life)
    else
        step4 = "getDesc() pcall → ok=" .. tostring(okD) .. "  d=" .. tostring(d)
    end
end

-- Étape 5 : getDesc().life via Airbase (si StaticObject a échoué)
local step5 = "getDesc().life (Airbase) → N/A"
if ab then
    local okD, d = pcall(function() return ab:getDesc() end)
    if okD and type(d) == "table" then
        step5 = "getDesc().life (Airbase) → " .. tostring(d.life)
    else
        step5 = "getDesc() via Airbase → ok=" .. tostring(okD) .. "  d=" .. tostring(d)
    end
end

-- Étape 6 : getTypeName
local step6 = "getTypeName → N/A"
local srcObj = so or ab
if srcObj then
    local okT, tn = pcall(function() return srcObj:getTypeName() end)
    step6 = "getTypeName → ok=" .. tostring(okT) .. "  name=" .. tostring(tn)
end

-- Cleanup
if ab  then pcall(function() ab:destroy() end) end
if so  then pcall(function() so:destroy() end) end

-- Rapport
local lines = {
    "=== DIAG Farp_FG_Petit_Helipad probe ===",
    "refPos: x=" .. string.format("%.0f", refX) .. "  z=" .. string.format("%.0f", refZ),
    step1,
    step2,
    step3,
    step4,
    step5,
    step6,
}
local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 40)
env.info("[DIAG] " .. msg:gsub("\n", " | "))
return msg
