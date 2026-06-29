---@diagnostic disable
-- tests/unit/player_spec.lua
-- busted specs for CTLDPlayer entity and CTLDPlayerManager singleton
-- Reference: live_tests/unit/U-026 through U-029
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayer entity construct + cargo helpers", function()
    -- U-026

    local playerObj

    before_each(function()
        playerObj = CTLDPlayer:new({
            unitName         = "test_unit",
            groupId          = 42,
            groupName        = "test_group",
            coalition        = coalition.side.BLUE,
            typeName         = "UH-1H",
            isTransport      = true,
            canCarryVehicles = false,
        })
    end)

    -- ── Constructor fields ────────────────────────────────────
    describe("constructor", function()

        it("new() returns non-nil", function()
            assert.is_not_nil(playerObj)
        end)

        it("unitName preserved", function()
            assert.equals("test_unit", playerObj.unitName)
        end)

        it("groupId preserved", function()
            assert.equals(42, playerObj.groupId)
        end)

        it("groupName preserved", function()
            assert.equals("test_group", playerObj.groupName)
        end)

        it("coalition preserved", function()
            assert.equals(coalition.side.BLUE, playerObj.coalition)
        end)

        it("typeName preserved", function()
            assert.equals("UH-1H", playerObj.typeName)
        end)

        it("isTransport preserved", function()
            assert.is_true(playerObj.isTransport)
        end)

        it("canCarryVehicles preserved", function()
            assert.is_false(playerObj.canCarryVehicles)
        end)

        it("loadedTroops empty at init", function()
            assert.equals(0, #playerObj.loadedTroops)
        end)

        it("loadedCrates empty at init", function()
            assert.equals(0, #playerObj.loadedCrates)
        end)

        it("loadedVehicles empty at init", function()
            assert.equals(0, #playerObj.loadedVehicles)
        end)

    end)

    -- ── addLoadedVehicle / removeLoadedVehicle ────────────────
    describe("addLoadedVehicle / removeLoadedVehicle", function()

        local veh1, veh2

        before_each(function()
            veh1 = { id = "veh_1" }
            veh2 = { id = "veh_2" }
        end)

        it("loadedVehicles == 1 after adding veh1", function()
            playerObj:addLoadedVehicle(veh1)
            assert.equals(1, #playerObj.loadedVehicles)
        end)

        it("loadedVehicles == 2 after adding veh1 + veh2", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            assert.equals(2, #playerObj.loadedVehicles)
        end)

        it("loadedVehicles == 1 after removing veh1 from {veh1, veh2}", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            playerObj:removeLoadedVehicle(veh1)
            assert.equals(1, #playerObj.loadedVehicles)
        end)

        it("veh2 remains after removing veh1", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            playerObj:removeLoadedVehicle(veh1)
            assert.equals(veh2, playerObj.loadedVehicles[1])
        end)

        it("loadedVehicles == 0 after removing both", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            playerObj:removeLoadedVehicle(veh1)
            playerObj:removeLoadedVehicle(veh2)
            assert.equals(0, #playerObj.loadedVehicles)
        end)

        it("removeLoadedVehicle absent object does not throw", function()
            assert.has_no_error(function()
                playerObj:removeLoadedVehicle({ id = "ghost" })
            end)
        end)

        it("loadedVehicles still 0 after remove on empty list", function()
            playerObj:removeLoadedVehicle(veh1)
            assert.equals(0, #playerObj.loadedVehicles)
        end)

    end)

    -- ── addLoadedCrate / removeLoadedCrate ────────────────────
    describe("addLoadedCrate / removeLoadedCrate", function()

        it("loadedCrates == 1 after addLoadedCrate", function()
            playerObj:addLoadedCrate({ id = "crate_A" })
            assert.equals(1, #playerObj.loadedCrates)
        end)

        it("loadedCrates == 0 after add + remove", function()
            local c = { id = "crate_A" }
            playerObj:addLoadedCrate(c)
            playerObj:removeLoadedCrate(c)
            assert.equals(0, #playerObj.loadedCrates)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager singleton + getPlayer nil", function()
    -- U-027

    before_each(function()
        CTLDPlayerManager._instance   = nil
        CTLDDCSEventBridge._instance  = nil
    end)

    it("getInstance() does not throw", function()
        assert.has_no_error(function() CTLDPlayerManager.getInstance() end)
    end)

    it("getInstance() returns non-nil", function()
        assert.is_not_nil(CTLDPlayerManager.getInstance())
    end)

    it("getInstance() is idempotent", function()
        local m1 = CTLDPlayerManager.getInstance()
        local m2 = CTLDPlayerManager.getInstance()
        assert.equals(m1, m2)
    end)

    it("getPlayer('unit_inexistante') == nil", function()
        assert.is_nil(CTLDPlayerManager.getInstance():getPlayer("unit_inexistante"))
    end)

    it("getPlayer('') == nil", function()
        assert.is_nil(CTLDPlayerManager.getInstance():getPlayer(""))
    end)

    it("getPlayer(nil) == nil", function()
        assert.is_nil(CTLDPlayerManager.getInstance():getPlayer(nil))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager _detectCapabilities", function()
    -- U-028

    local mgr

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
    end)

    local function mockUnit(typeName)
        local u = { _type = typeName }
        function u:getTypeName() return self._type end
        return u
    end

    -- UH-1H: in capabilitiesByType, canTransportWholeVehicle=true (CTLD_Next config)
    it("UH-1H: isTransport == true", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("UH-1H"))
        assert.is_true(isT)
    end)

    it("UH-1H: canCarryVehicles == true (CTLD_Next config)", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("UH-1H"))
        assert.is_true(canV)
    end)

    -- SK-60: in capabilitiesByType, canTransportWholeVehicle=false
    it("SK-60: isTransport == true", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("SK-60"))
        assert.is_true(isT)
    end)

    it("SK-60: canCarryVehicles == false", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("SK-60"))
        assert.is_false(canV)
    end)

    -- Hercules: in capabilitiesByType, canTransportWholeVehicle=true
    it("Hercules: isTransport == true", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("Hercules"))
        assert.is_true(isT)
    end)

    it("Hercules: canCarryVehicles == true", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("Hercules"))
        assert.is_true(canV)
    end)

    -- F-16C_50: not in capabilitiesByType
    it("F-16C_50: isTransport == false", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("F-16C_50"))
        assert.is_false(isT)
    end)

    it("F-16C_50: canCarryVehicles == false", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("F-16C_50"))
        assert.is_false(canV)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager onPlayerEnterUnit + onPlayerLeaveUnit", function()
    -- U-029

    local mgr

    local mockGroup = {
        _id   = 999,
        _name = "mock_grp_999",
    }
    function mockGroup:getID()   return self._id   end
    function mockGroup:getName() return self._name end

    local mockUnit = {
        _name = "mock_pilot",
        _type = "UH-1H",
        _coa  = coalition.side.BLUE,
    }
    function mockUnit:getName()       return self._name end
    function mockUnit:getTypeName()   return self._type end
    function mockUnit:getCoalition()  return self._coa  end
    function mockUnit:isExist()       return true        end
    function mockUnit:getPlayerName() return "MockPilot" end
    function mockUnit:getGroup()      return mockGroup   end

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
    end)

    -- ── onPlayerEnterUnit ────────────────────────────────────
    describe("onPlayerEnterUnit()", function()

        before_each(function()
            -- buildMenu may fail silently for fake groupId — pcall to isolate
            pcall(function()
                mgr:onPlayerEnterUnit({ initiator = mockUnit })
            end)
        end)

        it("getPlayer('mock_pilot') is non-nil after enter", function()
            assert.is_not_nil(mgr:getPlayer("mock_pilot"))
        end)

        it("unitName is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals("mock_pilot", p.unitName) end
        end)

        it("typeName is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals("UH-1H", p.typeName) end
        end)

        it("groupId is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals(999, p.groupId) end
        end)

        it("groupName is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals("mock_grp_999", p.groupName) end
        end)

        it("coalition is BLUE", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals(coalition.side.BLUE, p.coalition) end
        end)

        it("isTransport == true (UH-1H in capabilitiesByType)", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.is_true(p.isTransport) end
        end)

    end)

    -- ── onPlayerLeaveUnit ────────────────────────────────────
    describe("onPlayerLeaveUnit()", function()

        before_each(function()
            pcall(function()
                mgr:onPlayerEnterUnit({ initiator = mockUnit })
            end)
        end)

        it("does not throw", function()
            assert.has_no_error(function()
                mgr:onPlayerLeaveUnit({ initiator = mockUnit })
            end)
        end)

        it("getPlayer('mock_pilot') == nil after leave", function()
            mgr:onPlayerLeaveUnit({ initiator = mockUnit })
            assert.is_nil(mgr:getPlayer("mock_pilot"))
        end)

    end)

end)
