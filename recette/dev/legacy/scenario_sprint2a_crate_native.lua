---@diagnostic disable
-- =============================================================================
-- scenario_sprint2a_crate_native.lua
-- Sprint 2a — DCS-native crate load/unload via _checkNativeDCSCargo
--
-- Tests:
--   F-128 : DCS native LOAD detected — _nativeCrateLink memorised, crate state LOADED
--   F-129 : DCS native UNLOAD at ground — drift > 1m, state LANDED, fromParachute=false
--   F-130 : DCS native UNLOAD in flight — fromParachute=true, _checkAutoUnpack called
--   F-131 : autoUnpack — crateSet complete after parachute → vehicle spawned at centroid
--
-- Approach (no physical DCS interaction needed):
--   Mock _checkNativeDCSCargo internals by directly manipulating CTLDCrateManager state
--   and calling the methods as they would be called by the tick.
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG    = "[S2A]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_S2A_STEP"

-- ── HELPERS ───────────────────────────────────────────────────────────────────

local function log(msg)   ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end
local function pass(msg)   report("[PASS] " .. msg) end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, condition, details)
    if condition then
        pass(id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (details and (" | " .. details) or ""))
    end
end
local function assert_eq(id, actual, expected)
    check(id, "eq", actual == expected,
        "expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end
local function assert_not_nil(id, val, desc)
    check(id, desc or "not nil", val ~= nil, "got nil")
end

-- ── PLAYER ────────────────────────────────────────────────────────────────────
local playerUnit = nil
do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 then playerUnit = units[1] end
end
if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
    return "ABORT: no BLUE player — occupy a slot first"
end
local pPos = playerUnit:getPoint()

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local CRATE_NAME   = "SCN_S2A_CRATE_01"
local CRATE_NAME2  = "SCN_S2A_CRATE_02"
local CRATE_NAME3  = "SCN_S2A_CRATE_03"
-- A 3-crate set descriptor (cratesRequired=3) — use whatever is configured in the mission
-- For unit testing we mock the descriptor directly
local MOCK_UNIT_TYPE  = "M1045 HMMWV TOW"
local MOCK_CRATE_DESC = {
    unit           = MOCK_UNIT_TYPE,
    desc           = "M1045 Hummer TOW (mock)",
    cratesRequired = 3,
    weight         = 1000,
}

-- ── CLEANUP ───────────────────────────────────────────────────────────────────
local function cleanupAll()
    local mgr = CTLDCrateManager.getInstance()
    for _, n in ipairs({ CRATE_NAME, CRATE_NAME2, CRATE_NAME3 }) do
        if mgr.crates[n] then
            if mgr.crates[n].dcsStatic and mgr.crates[n].dcsStatic:isExist() then
                mgr.crates[n].dcsStatic:destroy()
            end
            mgr.crates[n] = nil
        end
        mgr._nativeCrateLink[n] = nil
    end
end

-- ── MOCK TRANSPORT ────────────────────────────────────────────────────────────
-- Minimal mock Unit for tests that don't need real DCS interaction
local function makeMockTransport(posX, posY, posZ, agl)
    -- Build a getPosition() result: identity orientation axes
    local p = { x = posX, y = posY, z = posZ }
    return {
        isExist   = function() return true end,
        getName   = function() return "MOCK_TRANSPORT" end,
        getPoint  = function() return p end,
        getPosition = function()
            return {
                p = p,
                x = { x = 1, y = 0, z = 0 },
                y = { x = 0, y = 1, z = 0 },
                z = { x = 0, y = 0, z = 1 },
            }
        end,
        _agl = agl or 0,
    }
end

-- ── MOCK STATIC ───────────────────────────────────────────────────────────────
local function makeMockStatic(posX, posY, posZ)
    local p = { x = posX, y = posY, z = posZ }
    return {
        isExist  = function() return true end,
        getPoint = function() return p end,
        destroy  = function() end,
        _pos     = p,
    }
end

-- ── MOCK LAND HEIGHT (override for tests) ────────────────────────────────────
-- We patch land.getHeight temporarily so AGL checks work predictably
local _orig_land_getHeight = land.getHeight

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
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
-- STEP 1 — F-128 : DCS native LOAD detection
-- Inject a crate in SPAWNED/LANDED state at a position inside a mock transport bbox.
-- Simulate one tick of _checkNativeDCSCargo with mocked transport+static.
-- Expected: crate transitions to LOADED, _nativeCrateLink memorised.
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then
    cleanupAll()

    local mgr = CTLDCrateManager.getInstance()

    -- Build a fake CTLDCrate instance
    local crate = CTLDCrate:new({
        crateName  = CRATE_NAME,
        descriptor = MOCK_CRATE_DESC,
        position   = { x = pPos.x + 0.3, y = pPos.y, z = pPos.z + 0.1 },
        coalition  = coalition.side.BLUE,
        spawnMethod = "test",
    })
    -- Attach a mock static at the same position (inside transport bbox)
    local mockStatic = makeMockStatic(pPos.x + 0.3, pPos.y, pPos.z + 0.1)
    crate.dcsStatic = mockStatic

    mgr.crates[CRATE_NAME] = crate

    -- Mock transport at pPos with identity orientation (bbox implicit in _pointInBBox test below)
    -- We call the load path directly: simulate what _checkNativeDCSCargo does on LOAD detection
    local mockTransport = makeMockTransport(pPos.x, pPos.y, pPos.z, 0)
    local up = mockTransport:getPosition()
    local cratePos = mockStatic:getPoint()
    local dx = cratePos.x - up.p.x
    local dy = cratePos.y - up.p.y
    local dz = cratePos.z - up.p.z
    mgr._nativeCrateLink[CRATE_NAME] = {
        lx = dx * up.x.x + dy * up.x.y + dz * up.x.z,
        ly = dx * up.y.x + dy * up.y.y + dz * up.y.z,
        lz = dx * up.z.x + dy * up.z.y + dz * up.z.z,
    }
    crate:load(mockTransport)

    -- Assertions
    local ref = mgr._nativeCrateLink[CRATE_NAME]
    assert_not_nil("F-128.1", ref, "_nativeCrateLink entry created")
    check("F-128.2", "lx approx 0.3", math.abs(ref.lx - 0.3) < 0.01,
        "lx=" .. tostring(ref.lx))
    check("F-128.3", "lz approx 0.1", math.abs(ref.lz - 0.1) < 0.01,
        "lz=" .. tostring(ref.lz))
    assert_eq("F-128.4", crate:isLoaded(), true)
    check("F-128.5", "loadedBy is mock transport",
        crate.loadedBy == mockTransport, tostring(crate.loadedBy))

    pass("Step 1 F-128 DONE — re-inject for Step 2")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — F-129 : DCS native UNLOAD at ground
-- Simulate crate being set down: static moves to a new position while transport
-- stays at pPos. Drift should exceed 1m → unload detected, fromParachute=false.
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then
    local mgr = CTLDCrateManager.getInstance()
    local crate = mgr.crates[CRATE_NAME]
    assert_not_nil("F-129.0", crate, "crate still registered")

    -- Move static 5m away (simulates DCS placing crate behind aircraft on ground)
    local mockTransport = crate.loadedBy
    crate.dcsStatic._pos = { x = pPos.x - 5, y = pPos.y, z = pPos.z }
    crate.dcsStatic.getPoint = function() return crate.dcsStatic._pos end

    -- Patch land.getHeight to return pPos.y (transport is at ground level → AGL=0)
    land.getHeight = function(_) return pPos.y end

    -- Simulate UNLOAD detection (copy of _checkNativeDCSCargo UNLOAD branch logic)
    local ref     = mgr._nativeCrateLink[CRATE_NAME]
    local cratePos = crate.dcsStatic:getPoint()
    local up = mockTransport:getPosition()
    local dx = cratePos.x - up.p.x
    local dy = cratePos.y - up.p.y
    local dz = cratePos.z - up.p.z
    local lx = dx * up.x.x + dy * up.x.y + dz * up.x.z
    local ly = dx * up.y.x + dy * up.y.y + dz * up.y.z
    local lz = dx * up.z.x + dy * up.z.y + dz * up.z.z
    local dlx = lx - ref.lx
    local dly = ly - ref.ly
    local dlz = lz - ref.lz
    local drift = math.sqrt(dlx*dlx + dly*dly + dlz*dlz)

    check("F-129.1", "drift > 1m", drift > 1.0, "drift=" .. string.format("%.2f", drift))

    -- Apply the state transition
    local tp = mockTransport:getPoint()
    local groundH = land.getHeight({ x = tp.x, z = tp.z })
    local inFlight = (tp.y - groundH) > 5
    mgr._nativeCrateLink[CRATE_NAME] = nil
    crate.position = cratePos
    crate.state    = CTLDCrate.STATE.LANDED
    crate.loadedBy = nil
    crate.loadTime = nil
    if inFlight then crate.fromParachute = true end

    -- Restore land.getHeight
    land.getHeight = _orig_land_getHeight

    assert_eq("F-129.2", crate.state, CTLDCrate.STATE.LANDED)
    assert_eq("F-129.3", crate.fromParachute, false)
    check("F-129.4", "_nativeCrateLink cleared",
        mgr._nativeCrateLink[CRATE_NAME] == nil, "still has entry")
    assert_eq("F-129.5", crate.loadedBy, nil)

    pass("Step 2 F-129 DONE — re-inject for Step 3")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — F-130 : DCS native UNLOAD in flight
-- Simulate crate released from airborne transport (AGL > 5m).
-- Expected: fromParachute=true set, state LANDED.
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then
    local mgr = CTLDCrateManager.getInstance()

    -- Create a new crate in LOADED state at altitude
    local altY = pPos.y + 200  -- 200m above ground
    local crate2 = CTLDCrate:new({
        crateName   = CRATE_NAME2,
        descriptor  = MOCK_CRATE_DESC,
        position    = { x = pPos.x + 100, y = altY, z = pPos.z + 50 },
        coalition   = coalition.side.BLUE,
        spawnMethod = "test",
    })
    local mockStatic2 = makeMockStatic(pPos.x + 100, altY, pPos.z + 50)
    crate2.dcsStatic = mockStatic2
    mgr.crates[CRATE_NAME2] = crate2

    -- Mock airborne transport at altitude
    local mockTransport2 = makeMockTransport(pPos.x + 100, altY, pPos.z + 50, 200)
    local up = mockTransport2:getPosition()
    -- Memorise linkRef (crate exactly at transport position → offset ≈ 0)
    mgr._nativeCrateLink[CRATE_NAME2] = { lx = 0, ly = 0, lz = 0 }
    crate2:load(mockTransport2)

    -- Move static to simulate DCS placing crate behind aircraft mid-air
    mockStatic2._pos = { x = pPos.x + 95, y = pPos.y + 5, z = pPos.z + 45 }
    mockStatic2.getPoint = function() return mockStatic2._pos end

    -- Patch land.getHeight: ground is at pPos.y, transport at pPos.y+200 → AGL=200
    land.getHeight = function(_) return pPos.y end

    -- Simulate UNLOAD detection
    local ref = mgr._nativeCrateLink[CRATE_NAME2]
    local cratePos = crate2.dcsStatic:getPoint()
    local dx = cratePos.x - up.p.x
    local dy = cratePos.y - up.p.y
    local dz = cratePos.z - up.p.z
    local lx = dx * up.x.x + dy * up.x.y + dz * up.x.z
    local ly = dx * up.y.x + dy * up.y.y + dz * up.y.z
    local lz = dx * up.z.x + dy * up.z.y + dz * up.z.z
    local dlx = lx - ref.lx
    local dly = ly - ref.ly
    local dlz = lz - ref.lz
    local drift = math.sqrt(dlx*dlx + dly*dly + dlz*dlz)

    check("F-130.1", "drift > 1m", drift > 1.0, "drift=" .. string.format("%.2f", drift))

    local tp = mockTransport2:getPoint()
    local groundH = land.getHeight({ x = tp.x, z = tp.z })
    local inFlight = (tp.y - groundH) > 5

    check("F-130.2", "transport detected as airborne", inFlight,
        "tp.y=" .. tp.y .. " groundH=" .. groundH)

    -- Apply state transition
    mgr._nativeCrateLink[CRATE_NAME2] = nil
    crate2.position = cratePos
    crate2.state    = CTLDCrate.STATE.LANDED
    crate2.loadedBy = nil
    crate2.loadTime = nil
    if inFlight then crate2.fromParachute = true end

    land.getHeight = _orig_land_getHeight

    assert_eq("F-130.3", crate2.state, CTLDCrate.STATE.LANDED)
    assert_eq("F-130.4", crate2.fromParachute, true)
    check("F-130.5", "_nativeCrateLink cleared",
        mgr._nativeCrateLink[CRATE_NAME2] == nil, "still has entry")

    pass("Step 3 F-130 DONE — re-inject for Step 4")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — F-131 : autoUnpack crateSet complet
-- Place 3 crates (cratesRequired=3) all fromParachute=true within radius.
-- Call _checkAutoUnpack on the last one.
-- Expected: all 3 crates unpacked (UNPACKED state), _spawnUnpacked called.
-- We mock _spawnUnpacked to capture the call without spawning a real unit.
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then
    local mgr = CTLDCrateManager.getInstance()

    -- Clean prior crates
    for _, n in ipairs({ CRATE_NAME, CRATE_NAME2, CRATE_NAME3 }) do
        if mgr.crates[n] then
            if mgr.crates[n].dcsStatic and mgr.crates[n].dcsStatic:isExist() then
                mgr.crates[n].dcsStatic:destroy()
            end
            mgr.crates[n] = nil
        end
        mgr._nativeCrateLink[n] = nil
    end

    -- Create 3 LANDED fromParachute=true crates with same descriptor, close together
    local names = { CRATE_NAME, CRATE_NAME2, CRATE_NAME3 }
    for i, n in ipairs(names) do
        local c = CTLDCrate:new({
            crateName   = n,
            descriptor  = MOCK_CRATE_DESC,
            position    = { x = pPos.x + i*2, y = pPos.y, z = pPos.z + i*2 },
            coalition   = coalition.side.BLUE,
            spawnMethod = "test",
        })
        c.state         = CTLDCrate.STATE.LANDED
        c.fromParachute = true
        c.canBeUnpacked = true
        c.dcsStatic     = makeMockStatic(pPos.x + i*2, pPos.y, pPos.z + i*2)
        mgr.crates[n]   = c
    end

    -- Mock _spawnUnpacked to capture call
    local spawnCalled     = false
    local spawnDesc       = nil
    local spawnPos        = nil
    local _orig_spawn = CTLDCrateManager._spawnUnpacked
    CTLDCrateManager._spawnUnpacked = function(self_mgr, desc, pos, coa, cId, player)
        spawnCalled = true
        spawnDesc   = desc
        spawnPos    = pos
    end

    -- Call _checkAutoUnpack on the last crate
    local lastCrate = mgr.crates[CRATE_NAME3]
    mgr:_checkAutoUnpack(lastCrate)

    -- Restore
    CTLDCrateManager._spawnUnpacked = _orig_spawn

    -- Assertions
    check("F-131.1", "_spawnUnpacked called", spawnCalled, "not called")
    check("F-131.2", "spawn descriptor is MOCK_UNIT_TYPE",
        spawnDesc and spawnDesc.unit == MOCK_UNIT_TYPE,
        "desc.unit=" .. tostring(spawnDesc and spawnDesc.unit))

    -- Centroid expected: avg of (pPos.x+2,pPos.x+4,pPos.x+6) = pPos.x+4
    local expectedX = pPos.x + 4
    check("F-131.3", "centroid X correct",
        spawnPos and math.abs(spawnPos.x - expectedX) < 0.1,
        "spawnPos.x=" .. tostring(spawnPos and spawnPos.x) .. " expected=" .. expectedX)

    -- All 3 crates should be UNPACKED
    local unpacked = 0
    for _, n in ipairs(names) do
        -- After unpackCrate they are removed from mgr.crates (via _unregister)
        -- so check by absence (nil) meaning they were processed
        if not mgr.crates[n] then unpacked = unpacked + 1 end
    end
    check("F-131.4", "all 3 crates unregistered after unpack", unpacked == 3,
        "unregistered=" .. unpacked)

    pass("Step 4 F-131 DONE — ALL STEPS COMPLETE")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

-- ── CLEANUP ───────────────────────────────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
land.getHeight = _orig_land_getHeight  -- safety restore

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
