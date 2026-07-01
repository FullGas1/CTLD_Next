---@diagnostic disable
-- diag_farp_getlife_meaning.lua
-- Vérifie ce que getLife() mesure réellement sur un heliport.

local name = "DIAG_GLM_001"
pcall(coalition.addStaticObject, country.id.USA, {
    name = name, type = "Farp_FG_Petit_Helipad", category = "Heliports",
    x = -355996 + 400, y = 618120 + 800000,
    heading = 0, start_time = 0,
    transportable = { randomTransportable = false }, dead = false,
})

local src = StaticObject.getByName(name) or Airbase.getByName(name)
local lines = { "=== getLife() meaning ===" }

-- Timer mission courant
local okT, mtime = pcall(timer.getTime)
lines[#lines+1] = "timer.getTime() = " .. tostring(okT and mtime or "ERR")

local okA, atime = pcall(timer.getAbsTime)
lines[#lines+1] = "timer.getAbsTime() = " .. tostring(okA and atime or "ERR")

if src then
    -- getLife sur l'objet
    local okL, lv = pcall(function() return src:getLife() end)
    lines[#lines+1] = "getLife() = " .. tostring(lv) .. "  (ok=" .. tostring(okL) .. ")"

    -- getLife sur un second objet identique (même valeur ?)
    local name2 = "DIAG_GLM_002"
    pcall(coalition.addStaticObject, country.id.USA, {
        name = name2, type = "Farp_FG_Petit_Helipad", category = "Heliports",
        x = -355996 + 450, y = 618120 + 800000,
        heading = 0, start_time = 0,
        transportable = { randomTransportable = false }, dead = false,
    })
    local src2 = StaticObject.getByName(name2) or Airbase.getByName(name2)
    if src2 then
        local okL2, lv2 = pcall(function() return src2:getLife() end)
        lines[#lines+1] = "getLife() (2nd instance) = " .. tostring(lv2)
        local ab2 = Airbase.getByName(name2)
        local so2 = StaticObject.getByName(name2)
        if ab2 then pcall(function() ab2:destroy() end) end
        if so2 then pcall(function() so2:destroy() end) end
    end

    -- Différence getLife() - timer.getTime() ?
    if okL and okT then
        lines[#lines+1] = "getLife() - getTime() = " .. tostring(lv - mtime)
        lines[#lines+1] = "getLife() - getAbsTime() = " .. tostring(lv - atime)
    end

    -- getLife() sur un GROUND unit (référence connue)
    local okG, groups = pcall(coalition.getGroups, coalition.side.BLUE)
    if okG and groups and #groups > 0 then
        local units = groups[1]:getUnits()
        if units and #units > 0 then
            local okUL, ulv = pcall(function() return units[1]:getLife() end)
            local okUL0, ul0 = pcall(function() return units[1]:getLife0() end)
            lines[#lines+1] = "GROUND unit getLife()  = " .. tostring(ulv)
            lines[#lines+1] = "GROUND unit getLife0() = " .. tostring(ul0)
        end
    end
end

local ab = Airbase.getByName(name)
local so = StaticObject.getByName(name)
if ab then pcall(function() ab:destroy() end) end
if so then pcall(function() so:destroy() end) end

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 60)
env.info("[DIAG_GLM] " .. msg:gsub("\n", " | "))
return msg
