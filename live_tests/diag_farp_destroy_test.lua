---@diagnostic disable
-- =============================================================================
-- diag_farp_destroy_test.lua
-- Teste la destruction d'un Invisible FARP spawné loin de tout appareil.
--
-- Injection 1 : spawn du FARP à 50 km à l'est
-- Injection 2 : test StaticObject:destroy() + Airbase:destroy() + vérification
-- Injection 3 : RESET (nettoyage + reset compteur)
-- =============================================================================

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

local TAG       = "[FARP-DESTROY]"
local FARP_NAME = "DIAG_TEST_FARP_1"
local STEP_KEY  = "_farp_destroy_step"

_G[STEP_KEY] = _G[STEP_KEY] or 1
local step = _G[STEP_KEY]

local lines = {}
local function say(msg)
    lines[#lines + 1] = msg
    trigger.action.outText(TAG .. " " .. msg, 25)
end

trigger.action.outText(TAG .. " ==== step=" .. step .. " ====", 8)

-- ── Trouver position 50 km est ───────────────────────────────────────────────
local function getSpawnPos()
    local ref
    local players = coalition.getPlayers(coalition.side.BLUE) or {}
    ref = players[1]
    if not ref then
        local grps = coalition.getGroups(coalition.side.BLUE) or {}
        if grps[1] then ref = grps[1]:getUnit(1) end
    end
    local pt = ref and ref:getPoint() or { x = -356000, y = 0, z = 618000 }
    local x = pt.x
    local z = pt.z + 50000  -- est = +z dans le système DCS
    return { x = x, y = land.getHeight({ x = x, y = z }), z = z }
end

-- ── Chercher le static par nom ───────────────────────────────────────────────
-- coalition.getStaticObjects() n'énumère PAS les Heliports → utiliser StaticObject.getByName()
local function findStatic(name)
    local ok, s = pcall(StaticObject.getByName, name)
    if ok and s and s:isExist() then return s end
    -- Fallback : scan (pour les non-Heliport)
    for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }) do
        for _, st in ipairs(coalition.getStaticObjects(coa) or {}) do
            local okN, n = pcall(function() return st:getName() end)
            if okN and n == name then return st end
        end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then
-- INJECTION 1 : Spawn FARP

    -- Cleanup résidu éventuel
    local old = findStatic(FARP_NAME)
    if old then pcall(function() old:destroy() end) end

    local pos = getSpawnPos()
    say(string.format("Spawn pos : (%.0f, %.0f, %.0f)", pos.x, pos.y, pos.z))

    local ok, obj = pcall(coalition.addStaticObject, country.id.USA, {
        name          = FARP_NAME,
        type          = "Invisible FARP",
        shape_name    = "invisiblefarp",
        category      = "Heliports",
        x             = pos.x,
        y             = pos.z,
        heading       = 0,
        start_time    = 0,
        dead          = false,
        transportable = { randomTransportable = false },
    })

    if ok and obj then
        say("FARP spawné OK. Ré-injecter pour step 2 (destroy test).")
        _G[STEP_KEY] = 2
    else
        say("ERREUR spawn : " .. tostring(obj))
    end

-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then
-- INJECTION 2 : Test destruction

    -- ── Test 1 : StaticObject:destroy() ──────────────────────────────────────
    say("=== TEST 1 : StaticObject:destroy() ===")
    local s = findStatic(FARP_NAME)
    local test1_done = false
    if not s then
        say("Static introuvable — spawn step 1 d'abord")
    else
        local okD, errD = pcall(function() s:destroy() end)
        say("destroy() → ok=" .. tostring(okD) .. " err=" .. tostring(errD))

        local still = findStatic(FARP_NAME)
        say("Static encore présent : " .. tostring(still ~= nil))
        if still then
            say("TEST 1 → FARP TOUJOURS LÀ (échec silencieux)")
        else
            say("TEST 1 → SUPPRIMÉ ✓")
            test1_done = true
        end
    end

    -- ── Test 2 : Airbase:destroy() (seulement si TEST 1 a échoué) ────────────
    if not test1_done then
        say("=== TEST 2 : Airbase:destroy() ===")
        local ab = Airbase.getByName(FARP_NAME)
        say("Airbase.getByName → " .. tostring(ab ~= nil))
        if ab then
            local okA, errA = pcall(function() ab:destroy() end)
            say("Airbase:destroy() → ok=" .. tostring(okA) .. " err=" .. tostring(errA))

            local ab2    = Airbase.getByName(FARP_NAME)
            local still2 = findStatic(FARP_NAME)
            say("Airbase encore présente : " .. tostring(ab2 ~= nil))
            say("Static encore présent   : " .. tostring(still2 ~= nil))
            if not ab2 and not still2 then
                say("TEST 2 → SUPPRIMÉ ✓")
            else
                say("TEST 2 → ÉCHOUE aussi (silencieux)")
            end
        else
            say("Airbase non créée par ce FARP → TEST 2 non applicable")
        end

        -- ── Test 3 : Airbase:getUnit(1):destroy() ────────────────────────────
        say("=== TEST 3 : Airbase:getUnit(1) ===")
        local ab3 = Airbase.getByName(FARP_NAME)
        if ab3 then
            local okU, u = pcall(function() return ab3:getUnit(1) end)
            say("getUnit(1) → ok=" .. tostring(okU) .. " result=" .. tostring(u))
            if okU and u then
                say("getUnit class=" .. tostring(type(u)))
                local okN, nm = pcall(function() return u:getName() end)
                say("getName → ok=" .. tostring(okN) .. " name=" .. tostring(nm))
                local okT, tp = pcall(function() return u:getTypeName() end)
                say("getTypeName → ok=" .. tostring(okT) .. " type=" .. tostring(tp))
                -- Tenter destroy sur l'objet retourné
                local okD2, errD2 = pcall(function() u:destroy() end)
                say("u:destroy() → ok=" .. tostring(okD2) .. " err=" .. tostring(errD2))
                -- Vérifier si airbase encore présente
                local ab4 = Airbase.getByName(FARP_NAME)
                local s4  = findStatic(FARP_NAME)
                say("Airbase après destroy : " .. tostring(ab4 ~= nil))
                say("Static après destroy  : " .. tostring(s4 ~= nil))
                if not ab4 and not s4 then
                    say("TEST 3 → SUPPRIMÉ ✓")
                else
                    say("TEST 3 → ÉCHOUE aussi")
                end
            else
                say("getUnit(1) → nil ou erreur")
            end
        end
    end

    _G[STEP_KEY] = 3

-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then
-- INJECTION 3 : Reset

    local s = findStatic(FARP_NAME)
    if s then pcall(function() s:destroy() end); say("Cleanup static tenté") end
    local ab = Airbase.getByName(FARP_NAME)
    if ab then pcall(function() ab:destroy() end); say("Cleanup airbase tentée") end
    _G[STEP_KEY] = 1
    say("RESET OK")
end
cfg.settings["debug"] = _saved_debug
return TAG .. " step=" .. step .. " | " .. table.concat(lines, " | ")
