---@diagnostic disable
-- diag_farp_fg_life_case.lua
-- Vérifie la casse de la clé life/Life dans getDesc() + getLife() si disponible.

local name = "DIAG_LIFE_001"
pcall(coalition.addStaticObject, country.id.USA, {
    name = name, type = "Farp_FG_Petit_Helipad", category = "Heliports",
    x = -355996 + 200, y = 618120 + 800000,
    heading = 0, start_time = 0,
    shape_name = "Farp_FG_Petit_Helipad.edm",
    transportable = { randomTransportable = false }, dead = false,
})

local src = StaticObject.getByName(name) or Airbase.getByName(name)
local lines = { "=== life/Life case check ===" }

if src then
    local okD, d = pcall(function() return src:getDesc() end)
    if okD and type(d) == "table" then
        -- Dump ALL keys avec casse exacte et valeur
        local keys = {}
        for k, v in pairs(d) do
            local vStr = type(v) == "table" and "(table)" or tostring(v)
            keys[#keys+1] = "[" .. tostring(k) .. "] = " .. vStr
        end
        table.sort(keys)
        lines[#lines+1] = "getDesc() keys:"
        for _, s in ipairs(keys) do lines[#lines+1] = "  " .. s end

        -- Accès directs
        lines[#lines+1] = "d.life  = " .. tostring(d.life)
        lines[#lines+1] = "d.Life  = " .. tostring(d.Life)
        lines[#lines+1] = "d['life'] = " .. tostring(d["life"])
        lines[#lines+1] = "d['Life'] = " .. tostring(d["Life"])
    else
        lines[#lines+1] = "getDesc() ERR: " .. tostring(d)
    end

    -- getLife() si existe
    local okL, lifeVal = pcall(function() return src:getLife() end)
    lines[#lines+1] = "getLife() → ok=" .. tostring(okL) .. "  val=" .. tostring(lifeVal)

    -- getLife0() (initiale) si existe
    local okL0, life0 = pcall(function() return src:getLife0() end)
    lines[#lines+1] = "getLife0() → ok=" .. tostring(okL0) .. "  val=" .. tostring(life0)
else
    lines[#lines+1] = "src = nil (objet introuvable)"
end

local ab = Airbase.getByName(name)
local so = StaticObject.getByName(name)
if ab then pcall(function() ab:destroy() end) end
if so then pcall(function() so:destroy() end) end

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 60)
env.info("[DIAG_LIFE] " .. msg:gsub("\n", " | "))
return msg
