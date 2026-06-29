---@diagnostic disable
-- diag_farp_fg_desc_compare.lua
-- Compare getDesc() entre un type mod valide (life=0) et un type invalide (life=0)
-- Objectif : trouver un discriminant fiable autre que life.

local function probeAndDump(typeName, shapeName, label)
    local name = "DIAG_CMP_" .. label
    local ok, obj = pcall(coalition.addStaticObject, country.id.USA, {
        name = name, type = typeName, category = "Heliports",
        x = -355996 + 50, y = 618120 + 800000,
        heading = 0, start_time = 0,
        shape_name = shapeName or "",
        transportable = { randomTransportable = false }, dead = false,
    })
    local result = { label = label, typeName = typeName }
    result.addOk  = ok
    result.objNil = (obj == nil)

    local so = StaticObject.getByName(name)
    local ab = Airbase.getByName(name)
    result.soFound = (so ~= nil)
    result.abFound = (ab ~= nil)

    local src = so or ab
    if src then
        local okD, d = pcall(function() return src:getDesc() end)
        if okD and type(d) == "table" then
            result.life       = d.life
            result.typeName2  = d.typeName
            result.displayName= d.displayName
            result.shape      = d.shape_name
            result.attributes = type(d.attributes) == "table" and "table" or tostring(d.attributes)
            -- Dump all keys
            local keys = {}
            for k, v in pairs(d) do
                if type(v) ~= "table" then
                    keys[#keys+1] = k .. "=" .. tostring(v)
                else
                    keys[#keys+1] = k .. "=(table)"
                end
            end
            table.sort(keys)
            result.allKeys = table.concat(keys, ", ")
        else
            result.descErr = tostring(d)
        end
        local okTN, tn = pcall(function() return src:getTypeName() end)
        result.getTypeName = okTN and tn or "ERR"
    end

    if ab then pcall(function() ab:destroy() end) end
    if so then pcall(function() so:destroy() end) end
    return result
end

local r1 = probeAndDump("Farp_FG_Petit_Helipad",       "Farp_FG_Petit_Helipad.edm", "MOD")
local r2 = probeAndDump("CTLD_INVALID_HELIPAD_XYZ_9999", "",                          "INV")

local function fmt(r)
    local lines = {
        "--- " .. r.label .. " (" .. r.typeName .. ") ---",
        "addOk=" .. tostring(r.addOk) .. "  objNil=" .. tostring(r.objNil),
        "StaticObj=" .. tostring(r.soFound) .. "  Airbase=" .. tostring(r.abFound),
        "life=" .. tostring(r.life) .. "  typeName2=" .. tostring(r.typeName2),
        "displayName=" .. tostring(r.displayName),
        "shape=" .. tostring(r.shape),
        "getTypeName=" .. tostring(r.getTypeName),
        "attributes=" .. tostring(r.attributes),
        "allKeys: " .. tostring(r.allKeys),
    }
    return table.concat(lines, "\n")
end

local msg = fmt(r1) .. "\n\n" .. fmt(r2)
trigger.action.outText(msg, 60)
env.info("[DIAG_CMP] " .. msg:gsub("\n", " | "))
return msg
