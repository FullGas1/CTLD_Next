-- diag_spawn_csfarp_uh1h.lua
-- Full cleanup of all Countryside FARP scene objects (by name prefix), then replay.

local banner = string.format("[DIAG CSFARP %s] Full cleanup + replay", os.date("%H:%M:%S"))
trigger.action.outText(banner, 8)

-- ── 1. Full cleanup by name prefix (handles re-injection = lost _spawnedObjs refs) ─────────────
-- Static prefixes from scene registry entries
local staticPrefixes = {
    "CS_FARP-",        -- Invisible_FARP entry (namePrefix="CS_FARP")
    "FARP_Tent-",      -- FARP_Tent
    "LightOn-",        -- NF-2_LightOn (namePrefix="LightOn")
    "Windsock-",       -- Windsock
    "ammo_box_cargo-", -- ammo_cargo (namePrefix="ammo_box_cargo")
    "CS_FARP_Flag_",   -- hardcoded flag names (CS_FARP_Flag_1..4)
}
-- Ground group prefixes from scene registry entries
local groupPrefixes = {
    "Fuel_Truck_Grp-",    -- Fuel_Truck
    "repare_Truck_Grp-",  -- repare_Truck
    "CS_FARP_Guard_Grp-", -- CS_FARP_Guards
    "CS_FARP_Flag_",      -- flags (older iterations used addGroup)
}

local function hasPrefix(name, prefixes)
    for _, pfx in ipairs(prefixes) do
        if name:sub(1, #pfx) == pfx then return true end
    end
    return false
end

local destroyed = 0

-- Statics (both coalitions, in case scene was triggered by RED)
for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }) do
    local statics = coalition.getStaticObjects(coa) or {}
    for _, s in ipairs(statics) do
        local ok, name = pcall(function() return s:getName() end)
        if ok and hasPrefix(name, staticPrefixes) then
            pcall(function() s:destroy() end)
            destroyed = destroyed + 1
        end
    end
    -- Ground groups
    local groups = coalition.getGroups(coa, Group.Category.GROUND) or {}
    for _, g in ipairs(groups) do
        local ok, name = pcall(function() return g:getName() end)
        if ok and hasPrefix(name, groupPrefixes) then
            pcall(function() g:destroy() end)
            destroyed = destroyed + 1
        end
    end
end

-- Also clear tracked scenes (in case CTLD was NOT re-injected)
local sm = CTLDSceneManager.getInstance()
sm._active = {}

trigger.action.outText(string.format("[DIAG CSFARP] Destroyed %d leftover object(s)", destroyed), 6)

-- ── 2. Prepare spawn point 80 m in front of unit ─────────────────────────────────────────────
local unitName = "Batumi_UH-1H_0-1"
local t = Unit.getByName(unitName)
if not t then
    trigger.action.outText("[DIAG CSFARP] ERROR: unit not found", 15)
    return "[DIAG CSFARP] unit not found"
end

local pt      = t:getPoint()
local realPos = t:getPosition()
local spawnPt = {
    x = pt.x + 80 * realPos.x.x,
    y = pt.y,
    z = pt.z + 80 * realPos.x.z,
}

local proxyUnit = {
    getPoint     = function() return spawnPt end,
    getPosition  = function()
        return { p = spawnPt, x = realPos.x, y = realPos.y, z = realPos.z }
    end,
    getName      = function() return unitName end,
    getGroup     = function() return t:getGroup() end,
    getCoalition = function() return t:getCoalition() end,
    getCountry   = function() return t:getCountry() end,
    isExist      = function() return true end,
}

-- ── 3. Play scene after 2 s delay (DCS needs time to flush destroyed objects) ────────────────
local _proxyUnit = proxyUnit
timer.scheduleFunction(function()
    local ok, err = pcall(function()
        CTLDSceneManager.getInstance():playScene(_proxyUnit, "Countryside FARP", nil, nil)
    end)
    if ok then
        trigger.action.outText("[DIAG CSFARP] Scene started — steps over 30 s", 12)
    else
        trigger.action.outText("[DIAG CSFARP] ERROR: " .. tostring(err), 20)
    end
end, nil, timer.getTime() + 3)
