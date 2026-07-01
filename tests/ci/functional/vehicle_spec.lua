---@diagnostic disable
-- tests/functional/vehicle_spec.lua
-- busted specs for CTLDVehicleSpawner
-- Reference: live_tests/functional/F-120, F-121, F-122, F-123
-- ============================================================

local function makeTransport(name)
    name = name or "UH-1H-T"
    return {
        _name    = name,
        getName      = function(self) return self._name end,
        getTypeName  = function(self) return "UH-1H" end,
        getCoalition = function(self) return coalition.side.BLUE end,
        getPoint     = function(self) return { x=0, y=10, z=0 } end,
        getPosition  = function(self) return { x={x=1,y=0,z=0}, p={x=0,y=10,z=0} } end,
        getGroup     = function(self) return { getID = function() return 9901 end } end,
        isExist      = function(self) return true end,
    }
end

local function makeVehicleUnit(name, x, z)
    return {
        _name      = name,
        _destroyed = false,
        getName      = function(self) return self._name end,
        isExist      = function(self) return true end,
        getPoint     = function(self) return { x = x or 10, y = 0, z = z or 10 } end,
        getCoalition = function(self) return coalition.side.BLUE end,
        getCountry   = function(self) return 2 end,
        destroy      = function(self) self._destroyed = true end,
    }
end

describe("CTLDVehicleSpawner", function()

    local vs
    local _origGs
    local mockTransport

    before_each(function()
        -- Reset singletons
        CTLDVehicleSpawner._instance  = nil
        CTLDPlayerManager._instance   = nil
        CTLDJTACManager._instance     = nil
        CTLDCrateManager._instance    = nil
        EventDispatcher._instance     = nil
        ctld.MenuManager._instance    = nil
        _cmInstance                   = nil

        _origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                return {
                    ["UH-1H"] = {
                        canTransportWholeVehicle = true,
                        maxWholeVehiclesOnboard  = 1,
                        loadableVehiclesBLUE     = { "M1045 HMMWV TOW" },
                        loadableVehiclesRED      = {},
                        troopsEnabled            = false,
                    }
                }
            end
            if k == "maximumDistancePackableUnitsSearch" then return 200 end
            if k == "nbLimitSpawnedTroops"               then return { 0, 0 } end
            if k == "JTAC_dropEnabled"                   then return true end
            return _origGs(k)
        end

        vs            = CTLDVehicleSpawner.getInstance()
        mockTransport = makeTransport("UH-1H-T")
    end)

    after_each(function()
        ctld.gs = _origGs
    end)

    -- ── F-120 : findLoadableVehicles + loadVehicle ───────────────────────────────
    describe("F-120 — findLoadableVehicles + loadVehicle menu_ctld", function()

        it("U-01: empty when no WAITING vehicles", function()
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(0, #r)
        end)

        it("U-02: finds WAITING vehicle in range", function()
            local u = makeVehicleUnit("f120_u", 10, 10)
            local veh = CTLDVehicle:new({
                id = "f120_v", vehicleType = "M1045 HMMWV TOW", unit = u,
                spawnData = { groupName="f120_v", unitName="f120_u",
                              vehicleType="M1045 HMMWV TOW", countryId=2, coalitionId=2 },
            })
            vs._vehicles["f120_v"]         = veh
            vs._unitToVehicle["f120_u"]    = "f120_v"
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(1, #r)
            assert.equals("M1045 HMMWV TOW", r[1].vehicleType)
            vs._vehicles["f120_v"]      = nil
            vs._unitToVehicle["f120_u"] = nil
        end)

        it("U-03: out-of-range vehicle excluded", function()
            local uNear = makeVehicleUnit("f120_near", 10, 10)
            local uFar  = makeVehicleUnit("f120_far", 9999, 0)
            local vNear = CTLDVehicle:new({
                id="f120_n", vehicleType="M1045 HMMWV TOW", unit=uNear,
                spawnData={groupName="f120_n",unitName="f120_near",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            local vFar = CTLDVehicle:new({
                id="f120_f", vehicleType="M1045 HMMWV TOW", unit=uFar,
                spawnData={groupName="f120_f",unitName="f120_far",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_n"] = vNear
            vs._vehicles["f120_f"] = vFar
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(1, #r)
            vs._vehicles["f120_n"] = nil
            vs._vehicles["f120_f"] = nil
        end)

        it("F-01: loadVehicle → state LOADED", function()
            local u = makeVehicleUnit("f120_lu", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_lv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_lv",unitName="f120_lu",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_lv"]         = veh
            vs._unitToVehicle["f120_lu"]    = "f120_lv"
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals(CTLDVehicle.STATE.LOADED, veh:getState())
            vs._vehicles["f120_lv"] = nil
        end)

        it("F-01: loadVehicle → unit destroyed", function()
            local u = makeVehicleUnit("f120_du", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_dv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_dv",unitName="f120_du",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_dv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.is_true(u._destroyed)
            vs._vehicles["f120_dv"] = nil
        end)

        it("F-01: loadVehicle → loadTransportName set", function()
            local u = makeVehicleUnit("f120_tn", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_tv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_tv",unitName="f120_tn",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_tv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals(mockTransport:getName(), veh.loadTransportName)
            vs._vehicles["f120_tv"] = nil
        end)

        it("F-01: loadVehicle → loadMethod == 'menu_ctld'", function()
            local u = makeVehicleUnit("f120_mu", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_mv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_mv",unitName="f120_mu",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_mv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals("menu_ctld", veh.loadMethod)
            vs._vehicles["f120_mv"] = nil
        end)

        it("U-04: LOADED vehicle no longer in findLoadableVehicles", function()
            local u = makeVehicleUnit("f120_xu", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_xv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_xv",unitName="f120_xu",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_xv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(0, #r)
            vs._vehicles["f120_xv"] = nil
        end)

    end)

    -- ── F-121 : findLoadedVehicles + unloadVehicle ───────────────────────────────
    describe("F-121 — findLoadedVehicles + unloadVehicle menu_ctld", function()

        local _origDynAdd

        before_each(function()
            _origDynAdd = ctld.utils.dynAdd
            ctld.utils.dynAdd = function(_, data)
                return { name = data and data.name or "f121_grp" }
            end
        end)

        after_each(function()
            ctld.utils.dynAdd = _origDynAdd
        end)

        it("U-05: findLoadedVehicles returns vehicle on this transport", function()
            local veh = CTLDVehicle:new({
                id="f121_v1", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_v1",unitName="f121_v1",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            vs._vehicles["f121_v1"] = veh
            local r = vs:findLoadedVehicles(mockTransport)
            assert.equals(1, #r)
            assert.equals("M1045 HMMWV TOW", r[1].vehicleType)
            vs._vehicles["f121_v1"] = nil
        end)

        it("U-06: vehicle on other transport not returned", function()
            local veh = CTLDVehicle:new({
                id="f121_v2", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_v2",unitName="f121_v2",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = "some_other_aircraft"
            vs._vehicles["f121_v2"] = veh
            local r = vs:findLoadedVehicles(mockTransport)
            assert.equals(0, #r)
            vs._vehicles["f121_v2"] = nil
        end)

        it("F-02: unloadVehicle → state WAITING", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "f121_u" then
                    return { getUnit = function(_)
                        return { getName=function() return "f121_u_unit" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local veh = CTLDVehicle:new({
                id="f121_u", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_u",unitName="f121_u_unit",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f121_u"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())

            Group.getByName = _origGetByName
            vs._vehicles["f121_u"] = nil
        end)

        it("F-02: unloadVehicle → dynAdd called", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "f121_d" then
                    return { getUnit = function(_)
                        return { getName=function() return "f121_d_unit" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local called = false
            ctld.utils.dynAdd = function(_, data)
                called = true
                return { name = data and data.name or "f121_d" }
            end

            local veh = CTLDVehicle:new({
                id="f121_d", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_d",unitName="f121_d_unit",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f121_d"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.is_true(called)

            Group.getByName = _origGetByName
            vs._vehicles["f121_d"] = nil
        end)

        it("U-07: findLoadedVehicles empty after unload", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "f121_e" then
                    return { getUnit = function(_)
                        return { getName=function() return "f121_e_unit" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local veh = CTLDVehicle:new({
                id="f121_e", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_e",unitName="f121_e_unit",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f121_e"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            local r = vs:findLoadedVehicles(mockTransport)
            assert.equals(0, #r)

            Group.getByName = _origGetByName
            vs._vehicles["f121_e"] = nil
        end)

    end)

    -- ── F-122 : JTAC lifecycle on load/unload ────────────────────────────────────
    describe("F-122 — JTAC lifecycle on loadVehicle / unloadVehicle", function()

        local _origDynAdd

        before_each(function()
            _origDynAdd = ctld.utils.dynAdd
            ctld.utils.dynAdd = function(_, data)
                return { name = data and data.name or "f122_grp" }
            end
        end)

        after_each(function()
            ctld.utils.dynAdd = _origDynAdd
        end)

        it("F-03: loadVehicle → setJTACInTransit called with correct group name", function()
            local jm = CTLDJTACManager.get()
            local transitCalls = {}
            local _origSet = jm.setJTACInTransit
            jm.setJTACInTransit = function(_, gName, _) table.insert(transitCalls, gName) end

            local u = makeVehicleUnit("f122_u", 5, 5)
            local veh = CTLDVehicle:new({
                id="f122_v", vehicleType="Soldier M249", unit=u,
                spawnData={groupName="F122_JTAC_GRP",unitName="f122_u",
                           vehicleType="Soldier M249",countryId=2,coalitionId=2},
            })
            vs._vehicles["f122_v"]        = veh
            vs._unitToVehicle["f122_u"]   = "f122_v"

            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")

            assert.equals(1, #transitCalls)
            assert.equals("F122_JTAC_GRP", transitCalls[1])

            jm.setJTACInTransit = _origSet
            vs._vehicles["f122_v"] = nil
        end)

        it("F-04: unloadVehicle → resumeJTAC called with correct group name", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "F122_JTAC_GRP2" then
                    return { getUnit = function(_)
                        return { getName=function() return "f122_u2" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local jm = CTLDJTACManager.get()
            local resumeCalls = {}
            local _origResume = jm.resumeJTAC
            jm.resumeJTAC = function(_, gName) table.insert(resumeCalls, gName) end

            local veh = CTLDVehicle:new({
                id="f122_v2", vehicleType="Soldier M249", unit=nil,
                spawnData={groupName="F122_JTAC_GRP2",unitName="f122_u2",
                           vehicleType="Soldier M249",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f122_v2"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")

            assert.equals(1, #resumeCalls)
            assert.equals("F122_JTAC_GRP2", resumeCalls[1])

            jm.resumeJTAC   = _origResume
            Group.getByName = _origGetByName
            vs._vehicles["f122_v2"] = nil
        end)

    end)

    -- ── F-123 : _dispatchPostSpawn registers non-JTAC GROUND vehicle ─────────────
    describe("F-123 — _spawnUnpacked registers non-JTAC GROUND vehicle", function()

        it("F-05: vehicle count increases after _spawnUnpacked (GROUND, non-JTAC)", function()
            local mgr  = CTLDCrateManager.getInstance()
            local tPos = mockTransport:getPoint()

            local countBefore = 0
            for _ in pairs(vs._vehicles) do countBefore = countBefore + 1 end

            local _origSpawn = ctld.utils.spawnFromDescriptor
            ctld.utils.spawnFromDescriptor = function() return true, nil end

            local _origUniqId = ctld.utils.getNextUniqId
            local _callCount  = 0
            ctld.utils.getNextUniqId = function()
                _callCount = _callCount + 1
                if _callCount == 1 then return 9900 end  -- gid
                if _callCount == 2 then return 9901 end  -- uid → CTLD_UNP_9901
                return _origUniqId()
            end

            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "CTLD_UNP_9901" then
                    return { getUnit = function(_)
                        return {
                            getName      = function() return "CTLD_UNP_9901_u" end,
                            isExist      = function() return true end,
                            getCoalition = function() return coalition.side.BLUE end,
                            getCountry   = function() return 2 end,
                            getPoint     = function() return tPos end,
                        } end }
                end
                return _origGetByName(name)
            end

            local fakeDesc = {
                unit = "M1045 HMMWV TOW", desc = "HMMWV TOW",
                spawnAs = "GROUND", isJTAC = false, cratesRequired = 1,
            }
            mgr:_spawnUnpacked(fakeDesc, tPos, coalition.side.BLUE, 2)

            local countAfter = 0
            for _ in pairs(vs._vehicles) do countAfter = countAfter + 1 end
            assert.equals(countBefore + 1, countAfter)

            -- Cleanup
            ctld.utils.spawnFromDescriptor = _origSpawn
            ctld.utils.getNextUniqId       = _origUniqId
            Group.getByName                = _origGetByName
            for id, v in pairs(vs._vehicles) do
                if v.vehicleType == "M1045 HMMWV TOW" then vs._vehicles[id] = nil end
            end
        end)

        it("U-08: findLoadableVehicles finds the unpack'd vehicle", function()
            local mgr  = CTLDCrateManager.getInstance()
            local tPos = { x = 5, y = 0, z = 5 }

            local _origSpawn = ctld.utils.spawnFromDescriptor
            ctld.utils.spawnFromDescriptor = function() return true, nil end

            local _origUniqId = ctld.utils.getNextUniqId
            local _callCount  = 0
            ctld.utils.getNextUniqId = function()
                _callCount = _callCount + 1
                if _callCount == 1 then return 9800 end
                if _callCount == 2 then return 9801 end  -- → CTLD_UNP_9801
                return _origUniqId()
            end

            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "CTLD_UNP_9801" then
                    return { getUnit = function(_)
                        return {
                            getName      = function() return "CTLD_UNP_9801_u" end,
                            isExist      = function() return true end,
                            getCoalition = function() return coalition.side.BLUE end,
                            getCountry   = function() return 2 end,
                            getPoint     = function() return tPos end,
                        } end }
                end
                return _origGetByName(name)
            end

            local fakeDesc = {
                unit = "M1045 HMMWV TOW", desc = "HMMWV TOW",
                spawnAs = "GROUND", isJTAC = false, cratesRequired = 1,
            }
            mgr:_spawnUnpacked(fakeDesc, tPos, coalition.side.BLUE, 2)

            -- Unit at tPos = {x=5,y=0,z=5}, transport at {x=0,y=10,z=0} → dist≈7m ≤200
            local near  = vs:findLoadableVehicles(makeTransport("UH-1H-T2"))
            local found = false
            for _, v in ipairs(near) do
                if v.vehicleType == "M1045 HMMWV TOW" then found = true end
            end
            assert.is_true(found)

            -- Cleanup
            ctld.utils.spawnFromDescriptor = _origSpawn
            ctld.utils.getNextUniqId       = _origUniqId
            Group.getByName                = _origGetByName
            for id, v in pairs(vs._vehicles) do
                if v.vehicleType == "M1045 HMMWV TOW" then vs._vehicles[id] = nil end
            end
        end)

    end)

end)
