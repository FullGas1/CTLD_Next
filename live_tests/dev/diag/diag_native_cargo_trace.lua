-- =============================================================================
-- diag_native_cargo_trace.lua
-- Diagnostic: observe dcsStatic:getPoint() behavior during DCS-native cargo load.
--
-- Injects a 1s polling loop that logs aircraft position, crate static position,
-- world-space offset (cratePos - aircraftPos), and distance.
-- At the first tick the offset is MEMORIZED. Subsequent ticks report the DELTA
-- from that baseline: near-zero delta = static tracks with aircraft (good);
-- growing delta = static is frozen at ground (detection approach must change).
--
-- Usage:
--   1. Adjust AIRCRAFT_NAME and CRATE_NAME below.
--   2. Inject via Witchcraft BEFORE you load the crate natively.
--   3. Load the crate (DCS keybind), fly, unload. Read CTLD.log.
--
-- If CRATE_NAME is unknown, first run diag_list_crates.lua to list CTLD crates.
-- =============================================================================

local AIRCRAFT_NAME = "uh1-1"    -- DCS unit name (as in mission editor)
local CRATE_NAME    = "cr1-1"    -- DCS static object name
local INTERVAL      = 1.0        -- log frequency in seconds
local MAX_TICKS     = 120        -- auto-stop after N seconds
local TAG           = "[NATIVE_CARGO]"

-- ── internal state ────────────────────────────────────────────────────────────
local _tick       = 0
local _baseOffset = nil   -- { dx, dy, dz, dist } memorized at first call

-- ── helpers ──────────────────────────────────────────────────────────────────
-- Look up crate static: try DCS name first, then search CTLD manager by CRATE_NAME prefix.
local function _findStatic()
    local s = StaticObject.getByName(CRATE_NAME)
    if s and s:isExist() then return s end
    -- Fallback: search CTLDCrateManager.crates for matching crateName
    local ok, mgr = pcall(CTLDCrateManager.getInstance)
    if ok and mgr then
        for name, crate in pairs(mgr.crates) do
            if string.find(name, CRATE_NAME, 1, true) then
                if crate.dcsStatic and crate.dcsStatic:isExist() then
                    env.info(TAG .. " resolved crate via CTLD manager: " .. name)
                    return crate.dcsStatic
                end
            end
        end
    end
    return nil
end

-- ── polling tick ─────────────────────────────────────────────────────────────
local function _tick_fn()
    _tick = _tick + 1
    if _tick > MAX_TICKS then
        env.info(TAG .. " diagnostic stopped after " .. MAX_TICKS .. " ticks.")
        return   -- do NOT reschedule
    end
    timer.scheduleFunction(_tick_fn, nil, timer.getTime() + INTERVAL)

    local aircraft = Unit.getByName(AIRCRAFT_NAME)
    local crStatic = _findStatic()

    -- ── aircraft absent ──
    if not aircraft or not aircraft:isExist() then
        env.info(string.format("%s TICK%03d  aircraft '%s' not found",
            TAG, _tick, AIRCRAFT_NAME))
        return
    end

    -- ── crate static absent ──
    if not crStatic then
        -- Check if CTLD has it as LOADED (dcsStatic may be nil for CTLD loads)
        local ok, mgr = pcall(CTLDCrateManager.getInstance)
        local ctldState = "unknown"
        if ok and mgr then
            for name, crate in pairs(mgr.crates) do
                if string.find(name, CRATE_NAME, 1, true) then
                    ctldState = crate.state
                    break
                end
            end
        end
        env.info(string.format("%s TICK%03d  crate static '%s' not found (CTLD state=%s)",
            TAG, _tick, CRATE_NAME, ctldState))
        return
    end

    local ap = aircraft:getPoint()
    local cp = crStatic:getPoint()

    local dx   = cp.x - ap.x
    local dy   = cp.y - ap.y
    local dz   = cp.z - ap.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    -- Also query CTLD crate state
    local ctldState = "?"
    local ok, mgr = pcall(CTLDCrateManager.getInstance)
    if ok and mgr then
        for name, crate in pairs(mgr.crates) do
            if string.find(name, CRATE_NAME, 1, true) then
                ctldState = crate.state
                break
            end
        end
    end

    -- ── first tick: memorize baseline ──
    if _baseOffset == nil then
        _baseOffset = { dx = dx, dy = dy, dz = dz, dist = dist }
        env.info(string.format(
            "%s TICK%03d  INIT  aircraft=(%.1f,%.1f,%.1f)  crate=(%.1f,%.1f,%.1f)"
            .. "  offset=(%.2f,%.2f,%.2f)  dist=%.2f  ctld=%s",
            TAG, _tick,
            ap.x, ap.y, ap.z,
            cp.x, cp.y, cp.z,
            dx, dy, dz, dist, ctldState))
    else
        -- delta from baseline
        local ddx   = dx   - _baseOffset.dx
        local ddy   = dy   - _baseOffset.dy
        local ddz   = dz   - _baseOffset.dz
        local ddist = dist - _baseOffset.dist

        -- Flag significant drift (> 1 m) to make unload events pop in the log
        local flag = ""
        if math.abs(ddist) > 1.0 then
            flag = "  *** DRIFT DETECTED ***"
        end

        env.info(string.format(
            "%s TICK%03d  aircraft=(%.1f,%.1f,%.1f)  crate=(%.1f,%.1f,%.1f)"
            .. "  offset=(%.2f,%.2f,%.2f)  dist=%.2f"
            .. "  DELTA=(%.2f,%.2f,%.2f)  ddist=%.2f  ctld=%s%s",
            TAG, _tick,
            ap.x, ap.y, ap.z,
            cp.x, cp.y, cp.z,
            dx, dy, dz, dist,
            ddx, ddy, ddz, ddist, ctldState, flag))
    end
end

-- ── start ─────────────────────────────────────────────────────────────────────
env.info(string.format(
    "%s diagnostic started  aircraft='%s'  crate='%s'  interval=%.1fs  max=%ds",
    TAG, AIRCRAFT_NAME, CRATE_NAME, INTERVAL, MAX_TICKS))
timer.scheduleFunction(_tick_fn, nil, timer.getTime() + 0.2)
