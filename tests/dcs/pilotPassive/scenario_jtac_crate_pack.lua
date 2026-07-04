---@diagnostic disable
-- =============================================================================
-- scenario_jtac_crate_pack.lua
-- JTAC vehicle (via crate) — pack → deregisterJTAC coverage
--
-- Simule le flow _spawnUnpacked(isJTAC=true) :
--   startLase + registerJTACVehicle → JTAC lase
-- Puis packVehicle() → deregisterJTAC silencieux
--
-- Steps :
--   Step 1 — Cleanup + spawn Hummer JTAC + startLase + registerJTACVehicle   (setup)
--   Step 2 — (T+3s) Assert JTAC LASING + packVehicle() + assert deregistered (F-132)
--   Step 3 — RESET
--
-- Prérequis : slot UH-1H BLUE occupé, posé au sol. Cible RED présente.
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[PACK_JTAC] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[PACK_JTAC]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_PACK_JTAC_STEP"

local function log(msg)    ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 40); log(msg) end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then report("[PASS] " .. id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (details and (" | " .. details) or "")) end
end

-- ── Player ────────────────────────────────────────────────────────────────────
local playerUnit = (coalition.getPlayers(coalition.side.BLUE) or {})[1]
if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
    return "ABORT: no BLUE player"
end
local playerName = playerUnit:getName()
local pPos       = playerUnit:getPoint()

-- ── Constants ─────────────────────────────────────────────────────────────────
local JTAC_GROUP  = "SCN_PACK_JTAC_HMR"
local JTAC_UNIT   = "SCN_PACK_JTAC_HMR_U1"
local JTAC_TYPE   = "Hummer"
local TARGET_GRP  = "SCN_PACK_JTAC_TARGET"
local TARGET_UNIT = "SCN_PACK_JTAC_TARGET_U1"
local TARGET_TYPE = "Hummer"
local COUNTRY_B   = 2   -- USA BLUE
local COUNTRY_R   = 0   -- Russia RED

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function spawnGround(groupName, unitName, uType, country, posX, posZ, heading)
    local existing = Group.getByName(groupName)
    if existing then existing:destroy() end
    return coalition.addGroup(country, Group.Category.GROUND, {
        name = groupName, task = "Ground Nothing",
        x = posX, y = posZ,
        units = {{ name=unitName, type=uType, x=posX, y=posZ,
                   heading=heading or 0, skill="Excellent", playerCanDrive=false }}
    })
end

local function cleanupAll()
    for _, gn in ipairs({JTAC_GROUP, TARGET_GRP}) do
        local g = Group.getByName(gn)
        if g then g:destroy() end
    end
    -- Deregister JTAC if stale
    local jm = CTLDJTACManager.get()
    if jm.jtacs and jm.jtacs[JTAC_GROUP] then
        jm:stopLase(JTAC_GROUP)
        jm.jtacs[JTAC_GROUP] = nil
    end
    -- Unregister vehicle if stale
    local vm = CTLDVehicleSpawner.getInstance()
    for id, veh in pairs(vm._vehicles) do
        if veh.spawnData and veh.spawnData.groupName == JTAC_GROUP then
            vm._vehicles[id] = nil
            break
        end
    end
end

-- ── State machine ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

if step == 1 then
    local f = io.open((cfg.settings["ctldLogPath"] or "") .. "CTLD.log", "w")
    if f then f:write("[" .. START .. "] === LOG RESET ===\n"); f:close() end
end

local _step_start = os.clock()
local _result = "INCOMPLETE"

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Setup : spawn Hummer JTAC + cible RED + startLase + register
-- Simule ce que fait _spawnUnpacked(desc.isJTAC=true)
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then
    cleanupAll()

    -- Spawn cible RED à 800m
    spawnGround(TARGET_GRP, TARGET_UNIT, TARGET_TYPE, COUNTRY_R, pPos.x + 800, pPos.z, 0)

    -- Spawn Hummer JTAC BLUE à 80m du joueur (dans portée pack)
    local jg = spawnGround(JTAC_GROUP, JTAC_UNIT, JTAC_TYPE, COUNTRY_B, pPos.x + 80, pPos.z, 0)
    check("F-132.S1.1", "Hummer JTAC spawned", jg ~= nil and Group.getByName(JTAC_GROUP) ~= nil)

    -- Simuler _spawnUnpacked(isJTAC=true) : startLase + registerJTACVehicle
    CTLDJTACManager.get():startLase(JTAC_GROUP, nil, nil, nil, nil, nil, nil)
    CTLDVehicleSpawner.getInstance():registerJTACVehicle(JTAC_GROUP, JTAC_TYPE, nil, nil)

    report("Step 1 done — startLase lancé (async +1s). Re-injecter dans 3s pour step 2.")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — F-132 : Assert JTAC LASING → packVehicle → assert deregistered
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then
    local jm = CTLDJTACManager.get()
    local vm = CTLDVehicleSpawner.getInstance()

    -- A) Vérifier JTAC est enregistré et lasing
    local jtac = jm.jtacs and jm.jtacs[JTAC_GROUP]
    check("F-132.1", "JTAC enregistré dans CTLDJTACManager",
        jtac ~= nil, "jtacs[" .. JTAC_GROUP .. "]=nil")

    if jtac then
        check("F-132.2", "JTAC state lasing ou idle (actif)",
            jtac.state == "lasing" or jtac.state == "idle" or jtac.state == "orbiting",
            "state=" .. tostring(jtac.state))
    end

    -- B) Vérifier vehicle enregistré dans CTLDVehicleSpawner
    local foundVeh = false
    for _, veh in pairs(vm._vehicles) do
        if veh.spawnData and veh.spawnData.groupName == JTAC_GROUP then
            foundVeh = true; break
        end
    end
    check("F-132.3", "vehicle JTAC enregistré dans CTLDVehicleSpawner", foundVeh)

    -- C) Vérifier laser code attribué
    local laserCodeAllocated = jtac and jtac.laserCode and jtac.laserCode > 0
    check("F-132.4", "laser code attribué", laserCodeAllocated,
        "laserCode=" .. tostring(jtac and jtac.laserCode))

    -- D) Appel packVehicle → doit appeler deregisterJTAC avant destroy
    local deregCalled = false
    local _origDereg = jm.deregisterJTAC
    jm.deregisterJTAC = function(self_jm, gname)
        if gname == JTAC_GROUP then deregCalled = true end
        return _origDereg(self_jm, gname)
    end

    local playerObj = { groupId = playerUnit:getGroup():getID(),
                        unitName = playerName,
                        coalition = playerUnit:getCoalition() }
    vm:packVehicle(playerName, JTAC_UNIT, playerObj)

    jm.deregisterJTAC = _origDereg  -- restore

    check("F-132.5", "deregisterJTAC appelé lors du pack",
        deregCalled, "jamais appelé")

    -- E) Vérifier JTAC bien retiré de CTLDJTACManager après pack
    local jtacAfter = jm.jtacs and jm.jtacs[JTAC_GROUP]
    check("F-132.6", "JTAC retiré de CTLDJTACManager après pack",
        jtacAfter == nil, "jtac encore présent state=" .. tostring(jtacAfter and jtacAfter.state))

    -- F) Info : destroy() appelé, groupe peut persister 1 tick DCS (comportement moteur attendu)
    local groupAfter = Group.getByName(JTAC_GROUP)
    local groupGone  = (groupAfter == nil or not groupAfter:isExist())
    report("F-132.7 [INFO] groupe après pack : " .. (groupGone and "détruit" or "encore visible 1 tick — OK"))

    report("Step 2 F-132 DONE — ALL PASS. Re-injecter pour RESET.")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Reset
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then
    cleanupAll()
    report("RESET done.")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " sans branche")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
