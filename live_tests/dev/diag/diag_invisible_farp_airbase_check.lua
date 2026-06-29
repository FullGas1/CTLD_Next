---@diagnostic disable
-- diag_invisible_farp_airbase_check.lua
-- Vérifie si coalition.addStaticObject avec type "Invisible FARP" crée bien
-- un airbase accessible via Airbase.getByName() et disposant d'une warehouse.

local TAG = "[DIAG_INV_FARP]"
local lines = { "=== Invisible FARP airbase check ===" }

-- Spawn d'un Invisible FARP via scripting
local sd = {
    name          = "TEST_InvFarp_01",
    type          = "Invisible FARP",
    shape_name    = "invisiblefarp",
    category      = "Heliports",
    x             = -27000,  -- position neutre hors de la scène
    y             = -3000,
    heading       = 0,
    start_time    = 0,
    dead          = false,
    heliport_frequency   = "127.5",
    heliport_callsign_id = 1,
    heliport_modulation  = 0,
    transportable = { randomTransportable = false },
}
local ok, obj = pcall(coalition.addStaticObject, country.id.USA, sd)
lines[#lines+1] = "addStaticObject ok=" .. tostring(ok) .. " obj=" .. tostring(obj)

if ok and obj then
    local spawnedName = obj:getName()
    lines[#lines+1] = "spawnedName=" .. tostring(spawnedName)

    -- Chercher par nom exact
    local ab = Airbase.getByName(spawnedName)
    lines[#lines+1] = "Airbase.getByName(spawnedName)=" .. tostring(ab)

    -- Chercher par nom fixe de la SD (DCS peut utiliser sd.name)
    local ab2 = Airbase.getByName("TEST_InvFarp_01")
    lines[#lines+1] = "Airbase.getByName('TEST_InvFarp_01')=" .. tostring(ab2)

    -- Lister tous les airbases pour voir si le spawn y apparait
    local allABs = coalition.getAirbases(coalition.side.BLUE) or {}
    if not allABs then allABs = {} end
    local abNames = {}
    for _, airbase in ipairs(allABs) do
        abNames[#abNames+1] = airbase:getName()
    end
    lines[#lines+1] = "Airbases BLUE (" .. #abNames .. "): " .. table.concat(abNames, ", ")

    -- Warehouse si airbase trouvé
    local foundAB = ab or ab2
    if foundAB then
        local w = foundAB:getWarehouse()
        lines[#lines+1] = "warehouse=" .. tostring(w)
    else
        lines[#lines+1] = "CONCLUSION: Invisible FARP NOT registered as DCS Airbase via scripting"
    end
end

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 30)
env.info(TAG .. " " .. msg:gsub("\n", " | "))
return msg
