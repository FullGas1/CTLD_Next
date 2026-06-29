---@diagnostic disable
-- diag_farp_fg_attributes.lua
-- Dump la table attributes de getDesc() pour MOD valide vs type invalide.

local function dumpAttributes(typeName, label)
    local name = "DIAG_ATT_" .. label
    pcall(coalition.addStaticObject, country.id.USA, {
        name = name, type = typeName, category = "Heliports",
        x = -355996 + 100, y = 618120 + 800000,
        heading = 0, start_time = 0,
        transportable = { randomTransportable = false }, dead = false,
    })
    local src = StaticObject.getByName(name) or Airbase.getByName(name)
    local attrStr = "N/A"
    if src then
        local okD, d = pcall(function() return src:getDesc() end)
        if okD and type(d) == "table" and type(d.attributes) == "table" then
            local keys = {}
            for k, v in pairs(d.attributes) do
                keys[#keys+1] = tostring(k) .. "=" .. tostring(v)
            end
            table.sort(keys)
            attrStr = #keys > 0 and table.concat(keys, ", ") or "(empty table)"
        else
            attrStr = "desc error or no attributes"
        end
    end
    local ab = Airbase.getByName(name)
    local so = StaticObject.getByName(name)
    if ab then pcall(function() ab:destroy() end) end
    if so then pcall(function() so:destroy() end) end
    return label .. " (" .. typeName .. "):\n  attributes: " .. attrStr
end

local r1 = dumpAttributes("Farp_FG_Petit_Helipad",        "MOD")
local r2 = dumpAttributes("CTLD_INVALID_HELIPAD_XYZ_9999", "INV")
local r3 = dumpAttributes("SINGLE_HELIPAD",                "BUILTIN")

local msg = r1 .. "\n\n" .. r2 .. "\n\n" .. r3
trigger.action.outText(msg, 60)
env.info("[DIAG_ATT] " .. msg:gsub("\n", " | "))
return msg
