---@diagnostic disable
-- tests/unit/beacon_spec.lua
-- busted specs for CTLDBeacon and CTLDBeaconManager frequency pools
-- Reference: live_tests/unit/U-014 through U-015
-- Note: timer.getTime() stub returns 0; endTime values chosen accordingly.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDBeacon battery + freqText", function()
    -- U-014

    local function makeBeacon(overrides)
        local data = {
            beaconName     = "TestBeacon",
            name           = "Beacon Test",
            coalitionId    = coalition.side.BLUE,
            position       = { x = 0, y = 0, z = 0 },
            vhfGroupName   = "vhf_grp",
            uhfGroupName   = "uhf_grp",
            fmGroupName    = "fm_grp",
            vhf            = 245000,       -- 245 kHz
            uhf            = 350500000,    -- 350.5 MHz
            fm             = 45200000,     -- 45.2 MHz
            batteryEndTime = -1,
            spawnTime      = 0,
            isFOB          = false,
        }
        if overrides then
            for k, v in pairs(overrides) do data[k] = v end
        end
        return CTLDBeacon:new(data)
    end

    -- ── Infinite battery (batteryEndTime=-1) ─────────────────
    describe("infinite battery (batteryEndTime=-1)", function()

        it("isBatteryAlive() returns true", function()
            assert.is_true(makeBeacon():isBatteryAlive())
        end)

        it("batteryRemaining() returns math.huge", function()
            assert.equals(math.huge, makeBeacon():batteryRemaining())
        end)

    end)

    -- ── Finite battery, alive (endTime > timer.getTime()=0) ──
    describe("finite battery, still alive", function()

        local b

        before_each(function()
            -- timer.getTime() stub = 0, endTime=1800 → alive
            b = makeBeacon({ batteryEndTime = 1800 })
        end)

        it("isBatteryAlive() returns true", function()
            assert.is_true(b:isBatteryAlive())
        end)

        it("batteryRemaining() returns 1800 (endTime - 0)", function()
            assert.equals(1800, b:batteryRemaining())
        end)

    end)

    -- ── Expired battery (endTime <= timer.getTime()=0) ────────
    describe("expired battery", function()

        local b

        before_each(function()
            -- timer.getTime() stub = 0, endTime=-60 → expired
            b = makeBeacon({ batteryEndTime = -60 })
        end)

        it("isBatteryAlive() returns false", function()
            assert.is_false(b:isBatteryAlive())
        end)

        it("batteryRemaining() returns 0", function()
            assert.equals(0, b:batteryRemaining())
        end)

    end)

    -- ── freqText formatting ──────────────────────────────────
    describe("freqText()", function()

        local txt

        before_each(function()
            txt = makeBeacon():freqText()
        end)

        it("returns a non-nil string", function()
            assert.equals("string", type(txt))
        end)

        it("contains '245.00 kHz'", function()
            assert.is_not_nil(txt:find("245.00 kHz"))
        end)

        it("contains '350.50'", function()
            assert.is_not_nil(txt:find("350.50"))
        end)

        it("contains '45.20 MHz'", function()
            assert.is_not_nil(txt:find("45.20 MHz"))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDBeaconManager _buildFreqPools", function()
    -- U-015
    -- Uses a lightweight instance (no init()) to avoid DCS-dependent side effects.

    local mgr

    before_each(function()
        mgr = setmetatable({}, CTLDBeaconManager)
        mgr._freeVHF = {}
        mgr._usedVHF = {}
        mgr._freeUHF = {}
        mgr._usedUHF = {}
        mgr._freeFM  = {}
        mgr._usedFM  = {}
        mgr:_buildFreqPools()
    end)

    -- ── VHF pool ─────────────────────────────────────────────
    describe("VHF pool", function()

        it("pool is non-empty", function()
            assert.is_true(#mgr._freeVHF > 0)
        end)

        it("all frequencies in range [200 kHz, 1250 kHz]", function()
            for _, f in ipairs(mgr._freeVHF) do
                assert.is_true(f >= 200000 and f <= 1250000,
                    "VHF freq out of range: " .. tostring(f))
            end
        end)

        it("no NDB frequencies included", function()
            local skipSet = {}
            for _, kHz in ipairs(CTLDBeaconManager._ndbSkip) do
                skipSet[kHz * 1000] = true
            end
            for _, f in ipairs(mgr._freeVHF) do
                assert.is_nil(skipSet[f], "NDB freq found in VHF pool: " .. tostring(f))
            end
        end)

    end)

    -- ── UHF pool ─────────────────────────────────────────────
    describe("UHF pool", function()

        it("pool is non-empty", function()
            assert.is_true(#mgr._freeUHF > 0)
        end)

        it("all frequencies >= 220 MHz", function()
            for _, f in ipairs(mgr._freeUHF) do
                assert.is_true(f >= 220000000,
                    "UHF freq below 220 MHz: " .. tostring(f))
            end
        end)

        it("all frequencies < 399 MHz", function()
            for _, f in ipairs(mgr._freeUHF) do
                assert.is_true(f < 399000000,
                    "UHF freq >= 399 MHz: " .. tostring(f))
            end
        end)

        it("no duplicate frequencies", function()
            local seen = {}
            for _, f in ipairs(mgr._freeUHF) do
                assert.is_nil(seen[f], "duplicate UHF freq: " .. tostring(f))
                seen[f] = true
            end
        end)

    end)

    -- ── FM pool ──────────────────────────────────────────────
    describe("FM pool", function()

        it("pool is non-empty", function()
            assert.is_true(#mgr._freeFM > 0)
        end)

        it("all frequencies in range [30 MHz, 76 MHz]", function()
            for _, f in ipairs(mgr._freeFM) do
                assert.is_true(f >= 30000000 and f <= 76000000,
                    "FM freq out of range: " .. tostring(f))
            end
        end)

    end)

end)
