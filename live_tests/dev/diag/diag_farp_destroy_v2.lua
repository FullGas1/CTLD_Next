---@diagnostic disable
-- =============================================================================
-- diag_farp_destroy_v2.lua
-- Test propre destroy Heliport — utilise world.getAirbases() pour compter.
-- Injection 1 : compte les FARPs existants + spawn 1 SINGLE_HELIPAD
-- Injection 2 : compte avant destroy, appelle destroy(), compte après
-- Injection 3 : reset compteur
-- =============================================================================

local FARP_NAME = "DIAG_FARP_V2"
local STEP_KEY  = "_farp_v2_step"
_G[STEP_KEY] = _G[STEP_KEY] or 1
local step = _G[STEP_KEY]

local results = {}
local function say(msg) results[#results+1] = msg; trigger.action.outText(msg, 25) end

-- Compte les airbases dont le nom contient FARP_NAME
local function countFarps()
    local n = 0
    local ab_found = nil
    for _, ab in ipairs(world.getAirbases() or {}) do
        local ok, nm = pcall(function() return ab:getName() end)
        if ok and nm == FARP_NAME then n = n + 1; ab_found = ab end
    end
    return n, ab_found
end

-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    local n0, _ = countFarps()
    say("FARPs '" .. FARP_NAME .. "' avant spawn : " .. n0)

    local batumi = Airbase.getByName("Batumi")
    local refPt  = batumi and batumi:getPoint() or { x = -355000, y = 0, z = 617000 }
    local sx, sz = refPt.x, refPt.z - 2037
    local okS, obj = pcall(coalition.addStaticObject, country.id.USA, {
        name = FARP_NAME, type = "SINGLE_HELIPAD",
        category = "Heliports", x = sx, y = sz, heading = 0,
        start_time = 0, dead = false, transportable = { randomTransportable = false },
    })
    if okS and obj then
        local n1, _ = countFarps()
        say("Spawn OK — FARPs après spawn : " .. n1 .. " (devrait être " .. (n0+1) .. ")")
        _G[STEP_KEY] = 2
    else
        say("ERREUR spawn : " .. tostring(obj))
    end

-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local n_before, ab = countFarps()
    say("FARPs avant destroy : " .. n_before)

    if not ab then
        say("Aucun FARP trouvé")
    else
        -- Destroy via Airbase:destroy()
        local okD = pcall(function() ab:destroy() end)
        say("ab:destroy() ok=" .. tostring(okD))

        local n_after, _ = countFarps()
        say("FARPs après destroy : " .. n_after)

        if n_after < n_before then
            say("RÉSULTAT → destroy() A FONCTIONNÉ (" .. n_before .. " → " .. n_after .. ")")
        else
            say("RÉSULTAT → destroy() ÉCHOUE (toujours " .. n_after .. ")")
        end

        -- Même test avec StaticObject
        local s = StaticObject.getByName(FARP_NAME)
        if s then
            local okS2 = pcall(function() s:destroy() end)
            say("StaticObject:destroy() ok=" .. tostring(okS2))
            local n_after2, _ = countFarps()
            say("FARPs après StaticObject:destroy() : " .. n_after2)
            if n_after2 < n_after then
                say("RÉSULTAT → StaticObject:destroy() A FONCTIONNÉ")
            else
                say("RÉSULTAT → StaticObject:destroy() ÉCHOUE aussi")
            end
        end
    end
    _G[STEP_KEY] = 3

elseif step == 3 then
    _G[STEP_KEY] = 1
    say("RESET OK")
end

return "step=" .. step .. " | " .. table.concat(results, " | ")
