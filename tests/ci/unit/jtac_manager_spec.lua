---@diagnostic disable
-- tests/unit/jtac_manager_spec.lua
-- busted specs for CTLDJTAC entity, CTLDJTACDetector, CTLDJTACManager, CTLDSceneManager
-- Reference: live_tests/unit/U-039 through U-043
-- CTLD_Next adaptations vs DCS-CTLD_FG references:
--   * CTLDJTACManager.get() is an alias for getInstance() — both valid
--   * No built-in scenes registered in CTLDSceneManager._registerBuiltins()
--   * Always pass smokeColor=0 to avoid nil trigger.smokeColor.Red
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDJTAC entity", function()

    local function makeJTAC(overrides)
        local data = {
            groupName    = "JTAC_Alpha",
            laserCode    = 1111,
            isFlying     = false,
            isInfantry   = true,
            coalitionId  = coalition.side.BLUE,
            smokeEnabled = false,
            smokeColor   = 0,
            lockMode     = "all",
        }
        if overrides then
            for k, v in pairs(overrides) do data[k] = v end
        end
        return CTLDJTAC:new(data)
    end

    local mockTarget = {
        unitName = "T-72#001",
        unitType = "T-72B",
        unitId   = 100,
        position = { x=0, y=0, z=0 },
    }

    local function makeSpot()
        local s = { _destroyed = false, _pos = nil }
        s.setPoint = function(self, p) self._pos = p end
        s.destroy  = function(self) self._destroyed = true end
        s.setCode  = function() end
        return s
    end

    -- ── Initial state (U-039) ─────────────────────────────────
    describe("initial state (U-039)", function()

        it("new() returns a non-nil object", function()
            assert.is_not_nil(makeJTAC())
        end)

        it("groupName is stored", function()
            assert.equals("JTAC_Alpha", makeJTAC().groupName)
        end)

        it("laserCode is stored", function()
            assert.equals(1111, makeJTAC().laserCode)
        end)

        it("isFlying is false", function()
            assert.is_false(makeJTAC().isFlying)
        end)

        it("isInfantry is true", function()
            assert.is_true(makeJTAC().isInfantry)
        end)

        it("state is IDLE", function()
            assert.equals(CTLDJTAC.STATE.IDLE, makeJTAC().state)
        end)

        it("currentTarget is nil", function()
            assert.is_nil(makeJTAC().currentTarget)
        end)

        it("radio is computed at init for valid code", function()
            assert.is_not_nil(makeJTAC().radio)
        end)

    end)

    -- ── State transitions (U-039) ─────────────────────────────
    describe("state transitions (U-039)", function()

        it("startLase transitions to LASING", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            assert.equals(CTLDJTAC.STATE.LASING, j.state)
        end)

        it("startLase sets currentTarget", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            assert.is_not_nil(j.currentTarget)
        end)

        it("startLase stores correct unitName", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            assert.equals("T-72#001", j.currentTarget.unitName)
        end)

        it("updateLaseSpot updates currentTarget.position", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            local newPos = { x=10, y=1, z=10 }
            j:updateLaseSpot(newPos)
            assert.equals(newPos, j.currentTarget.position)
        end)

        it("stopLase transitions LASING → IDLE", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            j:stopLase(CTLDJTAC.STOP_REASON.TARGET_LOST)
            assert.equals(CTLDJTAC.STATE.IDLE, j.state)
        end)

        it("stopLase clears currentTarget", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            j:stopLase(CTLDJTAC.STOP_REASON.TARGET_LOST)
            assert.is_nil(j.currentTarget)
        end)

        it("stopLase calls destroy() on laser spot", function()
            local j = makeJTAC()
            local spot = makeSpot()
            j:startLase(mockTarget, spot, makeSpot())
            j:stopLase(CTLDJTAC.STOP_REASON.TARGET_LOST)
            assert.is_true(spot._destroyed)
        end)

        it("startOrbit transitions to ORBITING", function()
            local j = makeJTAC()
            j:startOrbit(100)
            assert.equals(CTLDJTAC.STATE.ORBITING, j.state)
        end)

        it("startOrbit sets orbitStartTime", function()
            local j = makeJTAC()
            j:startOrbit(100)
            assert.is_not_nil(j.orbitStartTime)
        end)

        it("stopOrbit transitions ORBITING → IDLE", function()
            local j = makeJTAC()
            j:startOrbit(100)
            j:stopOrbit()
            assert.equals(CTLDJTAC.STATE.IDLE, j.state)
        end)

        it("stopOrbit clears orbitStartTime", function()
            local j = makeJTAC()
            j:startOrbit(100)
            j:stopOrbit()
            assert.is_nil(j.orbitStartTime)
        end)

        it("startLase during ORBITING keeps state ORBITING", function()
            local j = makeJTAC()
            j:startOrbit(200)
            j:startLase(mockTarget, makeSpot(), makeSpot())
            assert.equals(CTLDJTAC.STATE.ORBITING, j.state)
        end)

        it("setInTransit transitions to IN_TRANSIT", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            j:setInTransit()
            assert.equals(CTLDJTAC.STATE.IN_TRANSIT, j.state)
        end)

        it("setInTransit clears currentTarget", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            j:setInTransit()
            assert.is_nil(j.currentTarget)
        end)

        it("kill transitions to DEAD", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            j:kill()
            assert.equals(CTLDJTAC.STATE.DEAD, j.state)
        end)

        it("kill clears currentTarget", function()
            local j = makeJTAC()
            j:startLase(mockTarget, makeSpot(), makeSpot())
            j:kill()
            assert.is_nil(j.currentTarget)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDJTACDetector.calculateFMRadio", function()

    -- ── U-040 ─────────────────────────────────────────────────

    it("code 1111 returns a table", function()
        assert.equals("table", type(CTLDJTACDetector.calculateFMRadio("JTAC1", 1111)))
    end)

    it("code 1111: name == JTAC1", function()
        assert.equals("JTAC1", CTLDJTACDetector.calculateFMRadio("JTAC1", 1111).name)
    end)

    it("code 1111: mod == fm", function()
        assert.equals("fm", CTLDJTACDetector.calculateFMRadio("JTAC1", 1111).mod)
    end)

    it("code 1111: freq == 31.55", function()
        -- laserB=floor(111/100)=1, laserCD=11, freq=30+1+11*0.05=31.55
        assert.equals("31.55", CTLDJTACDetector.calculateFMRadio("JTAC1", 1111).freq)
    end)

    it("code 1688: freq == 40.4", function()
        -- laserB=6, laserCD=88, freq=30+6+88*0.05=40.4
        assert.equals("40.4", CTLDJTACDetector.calculateFMRadio("JTAC2", 1688).freq)
    end)

    it("code 1200: freq == 32", function()
        -- laserB=2, laserCD=0, freq=30+2+0=32
        assert.equals("32", CTLDJTACDetector.calculateFMRadio("JTAC3", 1200).freq)
    end)

    it("code 1155: freq == 33.75", function()
        -- laserB=1, laserCD=55, freq=30+1+55*0.05=33.75
        assert.equals("33.75", CTLDJTACDetector.calculateFMRadio("JTAC4", 1155).freq)
    end)

    it("code below range (1110) returns nil", function()
        assert.is_nil(CTLDJTACDetector.calculateFMRadio("G", 1110))
    end)

    it("code above range (1689) returns nil", function()
        assert.is_nil(CTLDJTACDetector.calculateFMRadio("G", 1689))
    end)

    it("nil code returns nil", function()
        assert.is_nil(CTLDJTACDetector.calculateFMRadio("G", nil))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDJTACDetector.calculateCorrectedSpot", function()

    -- ── U-041 ─────────────────────────────────────────────────
    local pos  = { x=100, y=10, z=200 }

    it("static target (vel=0, wind=0): x unchanged", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=0,y=0,z=0}, {x=0,y=0,z=0})
        assert.equals(100, r.x)
    end)

    it("static target: z unchanged", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=0,y=0,z=0}, {x=0,y=0,z=0})
        assert.equals(200, r.z)
    end)

    it("static target: y always == targetPos.y", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=0,y=0,z=0}, {x=0,y=0,z=0})
        assert.equals(10, r.y)
    end)

    it("moving target vel.x=10: x = 100 + 10*1.0 = 110", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=10,y=0,z=5}, {x=0,y=0,z=0})
        assert.equals(110, r.x)
    end)

    it("moving target vel.z=5: z = 200 + 5*1.0 = 205", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=10,y=0,z=5}, {x=0,y=0,z=0})
        assert.equals(205, r.z)
    end)

    it("wind.x=4: x = 100 - 4*1.05 = 95.8", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=0,y=0,z=0}, {x=4,y=0,z=2})
        assert.equals(95.8, r.x)
    end)

    it("wind.z=2: z = 200 - 2*1.05 = 197.9", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=0,y=0,z=0}, {x=4,y=0,z=2})
        assert.equals(197.9, r.z)
    end)

    it("wind.y unchanged even with wind", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=0,y=0,z=0}, {x=4,y=0,z=2})
        assert.equals(10, r.y)
    end)

    it("vel+wind combined: x = 100 + 10 - 4*1.05 = 105.8", function()
        local r = CTLDJTACDetector.calculateCorrectedSpot(pos, {x=10,y=0,z=0}, {x=4,y=0,z=0})
        assert.equals(105.8, r.x)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDJTACManager", function()

    before_each(function()
        CTLDJTACManager._instance = nil
    end)

    -- ── Singleton (U-042) ─────────────────────────────────────
    describe("singleton (U-042)", function()

        it("get() returns a non-nil instance", function()
            assert.is_not_nil(CTLDJTACManager.get())
        end)

        it("get() is idempotent", function()
            local m1 = CTLDJTACManager.get()
            local m2 = CTLDJTACManager.get()
            assert.equals(m1, m2)
        end)

        it("instance has jtacs table", function()
            assert.equals("table", type(CTLDJTACManager.get().jtacs))
        end)

        it("instance has _pendingJTACs table", function()
            assert.equals("table", type(CTLDJTACManager.get()._pendingJTACs))
        end)

    end)

    -- ── Laser pool (U-042) ────────────────────────────────────
    describe("laser pool (U-042)", function()

        local expectedCount = 1688 - 1111 + 1   -- 578

        it("_laserPool initialized with 578 codes", function()
            assert.equals(expectedCount, #CTLDJTACManager.get()._laserPool)
        end)

        it("_assignLaserCode returns 1688 first (tail removal)", function()
            assert.equals(1688, CTLDJTACManager.get():_assignLaserCode())
        end)

        it("_assignLaserCode reduces pool by 1", function()
            local m = CTLDJTACManager.get()
            m:_assignLaserCode()
            assert.equals(expectedCount - 1, #m._laserPool)
        end)

        it("second _assignLaserCode returns 1687", function()
            local m = CTLDJTACManager.get()
            m:_assignLaserCode()   -- 1688
            assert.equals(1687, m:_assignLaserCode())
        end)

        it("_freeLaserCode puts code back at tail of pool", function()
            local m = CTLDJTACManager.get()
            local code = m:_assignLaserCode()   -- 1688
            m:_assignLaserCode()                -- 1687
            m:_freeLaserCode(code)
            assert.equals(code, m._laserPool[#m._laserPool])
        end)

        it("_freeLaserCode(nil) does not raise", function()
            assert.has_no_error(function()
                CTLDJTACManager.get():_freeLaserCode(nil)
            end)
        end)

        it("_initLaserPool restores pool to full size", function()
            local m = CTLDJTACManager.get()
            m:_assignLaserCode()
            m:_assignLaserCode()
            m:_initLaserPool()
            assert.equals(expectedCount, #m._laserPool)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDSceneManager", function()

    -- Singleton uses module-local; reset via a test-unique unique name per test

    -- ── U-043 ─────────────────────────────────────────────────
    describe("singleton and registerSceneModel (U-043)", function()

        it("getInstance() returns non-nil", function()
            assert.is_not_nil(CTLDSceneManager.getInstance())
        end)

        it("getInstance() is idempotent", function()
            local m1 = CTLDSceneManager.getInstance()
            local m2 = CTLDSceneManager.getInstance()
            assert.equals(m1, m2)
        end)

        it("getModel for unknown name returns nil", function()
            assert.is_nil(CTLDSceneManager.getInstance():getModel("NonExistent_XYZ"))
        end)

        it("registerSceneModel(nil) returns false", function()
            assert.is_false(CTLDSceneManager.getInstance():registerSceneModel(nil))
        end)

        it("registerSceneModel with empty name returns false", function()
            assert.is_false(CTLDSceneManager.getInstance():registerSceneModel(
                { name="", steps={} }
            ))
        end)

        it("registerSceneModel valid model returns true", function()
            local ok = CTLDSceneManager.getInstance():registerSceneModel({
                name  = "TestScene_U43_A",
                steps = { { delayAfterPreviousStep=0, func=function(_ctx) end } },
            })
            assert.is_true(ok)
        end)

        it("getModel retrieves the registered model", function()
            CTLDSceneManager.getInstance():registerSceneModel({
                name="TestScene_U43_B", steps={},
            })
            assert.is_not_nil(CTLDSceneManager.getInstance():getModel("TestScene_U43_B"))
        end)

        it("duplicate registerSceneModel returns false", function()
            CTLDSceneManager.getInstance():registerSceneModel({
                name="TestScene_U43_C", steps={},
            })
            assert.is_false(CTLDSceneManager.getInstance():registerSceneModel({
                name="TestScene_U43_C", steps={},
            }))
        end)

    end)

end)
