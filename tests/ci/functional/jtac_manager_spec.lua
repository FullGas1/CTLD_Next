---@diagnostic disable
-- tests/functional/jtac_manager_spec.lua
-- busted specs for CTLDJTACManager
-- Reference: live_tests/functional/F-037, F-038, F-039, F-040
-- ============================================================

-- Ensure notifyCoalition stub exists
ctld.notifyCoalition = ctld.notifyCoalition or function() end

-- Helper: build a mock ground infantry group
local function makeMockGroup(name, unitName)
    local mockUnit = {
        _desc = { attributes = { Infantry = true } },
        getName      = function(self) return unitName end,
        getID        = function(self) return 9901 end,
        getTypeName  = function(self) return "Soldier M4 GRG" end,
        getPoint     = function(self) return { x=0, y=0, z=0 } end,
        getDesc      = function(self) return self._desc end,
    }
    return {
        _name  = name,
        _coa   = coalition.side.BLUE,
        getName       = function(self) return self._name end,
        getID         = function(self) return 9900 end,
        getCoalition  = function(self) return self._coa end,
        getUnits      = function(self) return { mockUnit } end,
        getUnit       = function(self, _) return mockUnit end,
        getController = function(self) return nil end,
        isExist       = function(self) return true end,
    }
end

describe("CTLDJTACManager", function()

    local mgr
    local _origGetByName

    before_each(function()
        CTLDJTACManager._instance = nil
        EventDispatcher._instance = nil
        _origGetByName = Group.getByName
        mgr = CTLDJTACManager.get()
    end)

    after_each(function()
        Group.getByName = _origGetByName
    end)

    -- ── F-037 : spawnJTAC ─────────────────────────────────────────
    describe("F-037 — spawnJTAC + OnJTACSpawned", function()

        it("spawnJTAC on unknown group → nil", function()
            assert.is_nil(mgr:spawnJTAC("NonExistentGroup", nil, nil))
        end)

        it("spawnJTAC with mock group → non-nil JTAC", function()
            local grp = makeMockGroup("JTAC_Grp_037", "JTAC_Unit_037")
            Group.getByName = function(n)
                if n == "JTAC_Grp_037" then return grp end
                return _origGetByName(n)
            end
            local jtac = mgr:spawnJTAC("JTAC_Grp_037", { laserCode=1200, smokeEnabled=false, lockMode="vehicle" }, nil)
            assert.is_not_nil(jtac)
        end)

        it("spawnJTAC → laserCode set correctly", function()
            local grp = makeMockGroup("JTAC_Grp_037b", "JTAC_Unit_037b")
            Group.getByName = function(n)
                if n == "JTAC_Grp_037b" then return grp end
                return _origGetByName(n)
            end
            local jtac = mgr:spawnJTAC("JTAC_Grp_037b", { laserCode=1200, smokeEnabled=false, lockMode="vehicle" }, nil)
            assert.equals(1200, jtac.laserCode)
        end)

        it("spawnJTAC → initial state IDLE", function()
            local grp = makeMockGroup("JTAC_Grp_037c", "JTAC_Unit_037c")
            Group.getByName = function(n)
                if n == "JTAC_Grp_037c" then return grp end
                return _origGetByName(n)
            end
            local jtac = mgr:spawnJTAC("JTAC_Grp_037c", { laserCode=1201, smokeEnabled=false, lockMode="all" }, nil)
            assert.equals(CTLDJTAC.STATE.IDLE, jtac.state)
        end)

        it("spawnJTAC publishes OnJTACSpawned with correct laserCode", function()
            local grp = makeMockGroup("JTAC_Grp_037d", "JTAC_Unit_037d")
            Group.getByName = function(n)
                if n == "JTAC_Grp_037d" then return grp end
                return _origGetByName(n)
            end
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACSpawned", function(p) received = p end)
            mgr:spawnJTAC("JTAC_Grp_037d", { laserCode=1202, smokeEnabled=false, lockMode="all" }, nil)
            assert.is_not_nil(received)
            assert.equals(1202, received.laserCode)
        end)

        it("getJTACByName returns the spawned JTAC", function()
            local grp = makeMockGroup("JTAC_Grp_037e", "JTAC_Unit_037e")
            Group.getByName = function(n)
                if n == "JTAC_Grp_037e" then return grp end
                return _origGetByName(n)
            end
            local jtac = mgr:spawnJTAC("JTAC_Grp_037e", { laserCode=1203, smokeEnabled=false, lockMode="all" }, nil)
            assert.equals(jtac, mgr:getJTACByName("JTAC_Grp_037e"))
        end)

        it("markPendingJTAC / _isPendingJTAC / _clearPendingJTAC lifecycle", function()
            mgr:markPendingJTAC("PendingGroup")
            assert.is_true(mgr:_isPendingJTAC("PendingGroup"))
            mgr:_clearPendingJTAC("PendingGroup")
            assert.is_false(mgr:_isPendingJTAC("PendingGroup"))
        end)

    end)

    -- ── F-038 : setJTACInTransit ──────────────────────────────────
    describe("F-038 — setJTACInTransit", function()

        local jtac
        local mockSpot = { setPoint=function()end, destroy=function()end }
        local transport = { unitName="uh1-1", playerName="Pilot" }

        before_each(function()
            jtac = CTLDJTAC:new({
                groupName    = "JTAC_Transit_038",
                laserCode    = 1300,
                isFlying     = false,
                isInfantry   = true,
                coalitionId  = coalition.side.BLUE,
                smokeEnabled = false,
                lockMode     = "all",
            })
            jtac:startLase({ unitName="T-72", unitType="T-72B", unitId=1, position={x=0,y=0,z=0} }, mockSpot, mockSpot)
            mgr.jtacs["JTAC_Transit_038"] = jtac
        end)

        it("JTAC is LASING before transit", function()
            assert.equals(CTLDJTAC.STATE.LASING, jtac.state)
        end)

        it("setJTACInTransit → state IN_TRANSIT", function()
            mgr:setJTACInTransit("JTAC_Transit_038", transport)
            assert.equals(CTLDJTAC.STATE.IN_TRANSIT, jtac.state)
        end)

        it("setJTACInTransit → currentTarget nil", function()
            mgr:setJTACInTransit("JTAC_Transit_038", transport)
            assert.is_nil(jtac.currentTarget)
        end)

        it("setJTACInTransit publishes OnJTACInTransit with correct payload", function()
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACInTransit", function(p) received = p end)
            mgr:setJTACInTransit("JTAC_Transit_038", transport)
            assert.is_not_nil(received)
            assert.equals("JTAC_Transit_038", received.jtac.groupName)
            assert.equals("uh1-1", received.transport.unitName)
        end)

        it("guard: DEAD JTAC → no OnJTACInTransit event", function()
            local jtac2 = CTLDJTAC:new({ groupName="JTAC_Dead_038", laserCode=1400,
                isFlying=false, isInfantry=true, coalitionId=coalition.side.BLUE,
                smokeEnabled=false, lockMode="all" })
            jtac2.state = CTLDJTAC.STATE.DEAD
            mgr.jtacs["JTAC_Dead_038"] = jtac2
            local fired = false
            EventDispatcher.getInstance():subscribe("OnJTACInTransit", function() fired = true end)
            mgr:setJTACInTransit("JTAC_Dead_038", transport)
            assert.is_false(fired)
        end)

        it("guard: unknown group → no OnJTACInTransit event", function()
            local fired = false
            EventDispatcher.getInstance():subscribe("OnJTACInTransit", function() fired = true end)
            mgr:setJTACInTransit("JTAC_Unknown_038", transport)
            assert.is_false(fired)
        end)

    end)

    -- ── F-039 : requestSmoke ──────────────────────────────────────
    describe("F-039 — requestSmoke", function()

        local jtac
        local targetPos = { x=500, y=10, z=800 }
        local mockSpot  = { setPoint=function()end, destroy=function()end }

        before_each(function()
            CTLDConfig.get().settings["JTAC_smokeMarginOfError"] = 0
            CTLDConfig.get().settings["JTAC_smokeOffset_y"]      = 2
            jtac = CTLDJTAC:new({
                groupName    = "JTAC_Smoke_039",
                laserCode    = 1111,
                isFlying     = false,
                isInfantry   = true,
                coalitionId  = coalition.side.BLUE,
                smokeEnabled = true,
                smokeColor   = trigger.smokeColor.Red,
                lockMode     = "all",
            })
            jtac:startLase({ unitName="T-55", unitType="T-55", unitId=42, position=targetPos }, mockSpot, mockSpot)
            mgr.jtacs["JTAC_Smoke_039"] = jtac
        end)

        it("requestSmoke publishes OnJTACSmokeTarget", function()
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACSmokeTarget", function(p) received = p end)
            mgr:requestSmoke("JTAC_Smoke_039")
            assert.is_not_nil(received)
        end)

        it("payload.jtac.groupName correct", function()
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACSmokeTarget", function(p) received = p end)
            mgr:requestSmoke("JTAC_Smoke_039")
            assert.equals("JTAC_Smoke_039", received.jtac.groupName)
        end)

        it("payload.smokeColor == Red", function()
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACSmokeTarget", function(p) received = p end)
            mgr:requestSmoke("JTAC_Smoke_039")
            assert.equals(trigger.smokeColor.Red, received.smokeColor)
        end)

        it("smokePos.x == targetPos.x (margin=0)", function()
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACSmokeTarget", function(p) received = p end)
            mgr:requestSmoke("JTAC_Smoke_039")
            assert.equals(targetPos.x, received.smokePosition.x)
        end)

        it("smokePos.y == targetPos.y + offset (2m)", function()
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACSmokeTarget", function(p) received = p end)
            mgr:requestSmoke("JTAC_Smoke_039")
            assert.equals(targetPos.y + 2, received.smokePosition.y)
        end)

        it("guard: no active target → no event", function()
            local jtac2 = CTLDJTAC:new({ groupName="JTAC_NoTarget_039", laserCode=1222,
                isFlying=false, isInfantry=true, coalitionId=coalition.side.BLUE,
                smokeEnabled=true, lockMode="all" })
            mgr.jtacs["JTAC_NoTarget_039"] = jtac2
            local fired = false
            EventDispatcher.getInstance():subscribe("OnJTACSmokeTarget", function() fired = true end)
            mgr:requestSmoke("JTAC_NoTarget_039")
            assert.is_false(fired)
        end)

        it("guard: unknown JTAC → no event", function()
            local fired = false
            EventDispatcher.getInstance():subscribe("OnJTACSmokeTarget", function() fired = true end)
            mgr:requestSmoke("JTAC_Unknown_039")
            assert.is_false(fired)
        end)

    end)

    -- ── F-040 : killJTAC ─────────────────────────────────────────
    describe("F-040 — killJTAC", function()

        local jtac
        local assignedCode = 1500
        local poolBefore
        local mockSpot = { setPoint=function()end, destroy=function()end }

        before_each(function()
            -- Remove 1500 from pool to simulate it being assigned
            for i, c in ipairs(mgr._laserPool) do
                if c == assignedCode then table.remove(mgr._laserPool, i) break end
            end
            poolBefore = #mgr._laserPool

            jtac = CTLDJTAC:new({
                groupName    = "JTAC_Kill_040",
                laserCode    = assignedCode,
                isFlying     = false,
                isInfantry   = true,
                coalitionId  = coalition.side.BLUE,
                smokeEnabled = false,
                lockMode     = "all",
            })
            jtac:startLase({ unitName="BMP-2", unitType="BMP-2", unitId=77, position={x=0,y=0,z=0} },
                mockSpot, mockSpot)
            mgr.jtacs["JTAC_Kill_040"] = jtac
        end)

        it("killJTAC → state DEAD", function()
            mgr:killJTAC("JTAC_Kill_040", { unitName="F-16C", playerName="Viper" })
            assert.equals(CTLDJTAC.STATE.DEAD, jtac.state)
        end)

        it("killJTAC → currentTarget nil", function()
            mgr:killJTAC("JTAC_Kill_040", { unitName="F-16C", playerName="Viper" })
            assert.is_nil(jtac.currentTarget)
        end)

        it("killJTAC publishes OnJTACDead with correct groupName", function()
            local received = nil
            EventDispatcher.getInstance():subscribe("OnJTACDead", function(p) received = p end)
            mgr:killJTAC("JTAC_Kill_040", { unitName="F-16C", playerName="Viper" })
            assert.is_not_nil(received)
            assert.equals("JTAC_Kill_040", received.jtac.groupName)
        end)

        it("killJTAC → JTAC removed from registry", function()
            mgr:killJTAC("JTAC_Kill_040", { unitName="F-16C", playerName="Viper" })
            assert.is_nil(mgr:getJTACByName("JTAC_Kill_040"))
        end)

        it("killJTAC → laser code freed (pool +1)", function()
            mgr:killJTAC("JTAC_Kill_040", { unitName="F-16C", playerName="Viper" })
            assert.equals(poolBefore + 1, #mgr._laserPool)
        end)

        it("guard: killJTAC on unknown group → no OnJTACDead event", function()
            local fired = false
            EventDispatcher.getInstance():subscribe("OnJTACDead", function() fired = true end)
            mgr:killJTAC("JTAC_Unknown_040", nil)
            assert.is_false(fired)
        end)

    end)

end)
