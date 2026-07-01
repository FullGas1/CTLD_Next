---@diagnostic disable
-- diag_farp_fg_getlife_compare.lua
-- Compare getLife() entre mod valide, type invalide et SINGLE_HELIPAD built-in.

local function probeGetLife(typeName, label, offsetX)
    local name = "DIAG_GL_" .. label
    pcall(coalition.addStaticObject, country.id.USA, {
        name = name, type = typeName, category = "Heliports",
        x = -355996 + offsetX, y = 618120 + 800000,
        heading = 0, start_time = 0,
        transportable = { randomTransportable = false }, dead = false,
    })
    local src = StaticObject.getByName(name) or Airbase.getByName(name)
    local lifeVal = "N/A (src nil)"
    local descLife = "N/A"
    if src then
        local okL, lv = pcall(function() return src:getLife() end)
        lifeVal = okL and tostring(lv) or ("ERR:" .. tostring(lv))
        local okD, d = pcall(function() return src:getDesc() end)
        descLife = (okD and type(d) == "table") and tostring(d.life) or "ERR"
    end
    local ab = Airbase.getByName(name)
    local so = StaticObject.getByName(name)
    if ab then pcall(function() ab:destroy() end) end
    if so then pcall(function() so:destroy() end) end
    return string.format("%-10s %-40s  getLife()=%s  desc.life=%s",
        label, typeName, lifeVal, descLife)
end

local lines = {
    "=== getLife() comparison ===",
    probeGetLife("Farp_FG_Petit_Helipad",        "MOD",     300),
    probeGetLife("CTLD_INVALID_HELIPAD_XYZ_9999", "INVALID", 310),
    probeGetLife("SINGLE_HELIPAD",                "BUILTIN", 320),
    probeGetLife("FARP",                          "FARP",    330),
}

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 60)
env.info("[DIAG_GL] " .. msg:gsub("\n", " | "))
return msg
