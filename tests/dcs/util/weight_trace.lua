-- =============================================================================
-- weight_trace.lua  — Diagnostic: DCS cargo weight tracking
-- =============================================================================
-- Uses Unit:getCargosOnBoard() (v2.5.5) to read loaded cargos directly.
-- Also wraps trigger.action.setUnitInternalCargo to intercept CTLD weight calls.
--
-- Stop: _WT_STOP()   or reinject this script
-- =============================================================================

local INTERVAL  = 1
local DISPLAY_S = 5

-- Kill previous instance + restore wrapped fn
if type(_WT_STOP) == "function" then _WT_STOP() end
if type(_WT_ORIG_SET_CARGO) == "function" then
    trigger.action.setUnitInternalCargo = _WT_ORIG_SET_CARGO
    _WT_ORIG_SET_CARGO = nil
end

local _stop     = false
local _step     = 0
local _unitName = nil
local _lastSummary = ""

_WT_STOP = function()
    _stop = true
    if type(_WT_ORIG_SET_CARGO) == "function" then
        trigger.action.setUnitInternalCargo = _WT_ORIG_SET_CARGO
        _WT_ORIG_SET_CARGO = nil
    end
    trigger.action.outText("[WT] STOPPED", 5)
    env.info("[WT] weight_trace STOPPED")
end

-- ---------------------------------------------------------------------------
-- 1. Intercept setUnitInternalCargo
-- ---------------------------------------------------------------------------
_WT_ORIG_SET_CARGO = trigger.action.setUnitInternalCargo
trigger.action.setUnitInternalCargo = function(unitName, weight)
    local msg = string.format("[WT] >>> setUnitInternalCargo(%s, %.1f kg)", unitName, weight or 0)
    trigger.action.outText(msg, DISPLAY_S + 3)
    env.info(msg)
    return _WT_ORIG_SET_CARGO(unitName, weight)
end

-- ---------------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------------
local function findPlayerHelo()
    if _unitName then
        local u = Unit.getByName(_unitName)
        if u and u:isExist() then return u end
        _unitName = nil
    end
    local groups = coalition.getGroups(coalition.side.BLUE, Group.Category.HELICOPTER)
    for _, grp in ipairs(groups or {}) do
        for _, u in ipairs(grp:getUnits() or {}) do
            if u and u:isExist() and u:isActive() then return u end
        end
    end
    return nil
end

local function getCargosOnBoard(unit)
    local ok, cargos = pcall(function() return unit:getCargosOnBoard() end)
    if not ok or type(cargos) ~= "table" then return {} end
    return cargos
end

local function cargoSummary(cargos)
    if #cargos == 0 then return "EMPTY (0 cargos)" end
    local totalMass = 0
    local names = {}
    for i, cargo in ipairs(cargos) do
        local name, mass = "?", 0
        -- Try getCargoDisplayName
        local ok1, n = pcall(function() return cargo:getCargoDisplayName() end)
        if ok1 and n then name = n end
        -- Try getName as fallback
        if name == "?" then
            local ok2, n2 = pcall(function() return cargo:getName() end)
            if ok2 and n2 then name = n2 end
        end
        -- Try getCargoWeight (StaticObject method)
        local ok3, w = pcall(function() return cargo:getCargoWeight() end)
        if ok3 and w then mass = w end
        totalMass = totalMass + mass
        names[i] = string.format("%s(%.0fkg)", name, mass)
    end
    return string.format("%d cargo(s) | total=%.1f kg | %s", #cargos, totalMass, table.concat(names, ", "))
end

-- ---------------------------------------------------------------------------
-- 3. Poll
-- ---------------------------------------------------------------------------
local function poll()
    if _stop then return nil end
    _step = _step + 1

    local unit = findPlayerHelo()
    if not unit then
        if _step % 5 == 0 then
            trigger.action.outText("[WT] Helo not found...", DISPLAY_S)
        end
        return timer.getTime() + INTERVAL
    end
    _unitName = unit:getName()

    local cargos  = getCargosOnBoard(unit)
    local summary = cargoSummary(cargos)

    local changed = (summary ~= _lastSummary)
    if changed then
        local msg = string.format("[WT] #%d *** CHANGE: %s", _step, summary)
        trigger.action.outText(msg, DISPLAY_S + 2)
        env.info(msg)
        _lastSummary = summary
    elseif _step % 5 == 0 then
        local msg = string.format("[WT] #%d | %s", _step, summary)
        trigger.action.outText(msg, DISPLAY_S)
        env.info(msg)
    end

    return timer.getTime() + INTERVAL
end

-- ---------------------------------------------------------------------------
timer.scheduleFunction(poll, nil, timer.getTime() + 0.3)
local startMsg = "[WT] weight_trace v4 (getCargosOnBoard) | stop: _WT_STOP()"
trigger.action.outText(startMsg, 8)
env.info(startMsg)
return "weight_trace v4 OK"
