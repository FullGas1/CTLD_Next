---@diagnostic disable
-- tests/functional/troop_manager_spec.lua
-- busted specs for CTLDTroopManager
-- Reference: live_tests/functional/F-033, F-034, F-035, F-036
-- ============================================================

-- ── Shared helpers ────────────────────────────────────────────────────────────

local function makeUnit(name, coa)
    coa = coa or coalition.side.BLUE
    return {
        _name    = name,
        getName      = function(self) return self._name end,
        getCoalition = function(self) return coa end,
        getCountry   = function(self) return 2 end,
        getTypeName  = function(self) return "UH-1H" end,
        getPoint     = function(self) return { x=0, y=5, z=0 } end,
        getPosition  = function(self)
            return { x={x=1,y=0,z=0}, p={x=0,y=5,z=0} }
        end,
        getVelocity  = function(self) return { x=0, y=0, z=0 } end,
        getGroup     = function(self) return { getID = function() return 9901 end } end,
        isExist      = function(self) return true end,
    }
end

-- Minimal zone mock compatible with embarkFromTroopZone / returnToTroopZone
local function makeZone(overrides)
    local z = {
        coalition        = 0,
        active           = true,
        pickMaxStock     = 0,      -- 0 = unlimited
        pickCurrentStock = 10,
        zoneName         = "TRZ_test",
        isInZone         = function(self, _) return true end,
        hasPickup        = function(self) return true end,
        consumeStock     = function(self, n)
            if self.pickMaxStock ~= 0 then
                self.pickCurrentStock = self.pickCurrentStock - n
            end
        end,
        restoreStock     = function(self, n)
            if self.pickMaxStock ~= 0 then
                self.pickCurrentStock = self.pickCurrentStock + n
            end
        end,
    }
    for k, v in pairs(overrides or {}) do z[k] = v end
    return z
end

-- Minimal template (total=4: inf=3, mg=1)
local function makeTemplate(overrides)
    local t = {
        name           = "Alpha Squad",
        total          = 4,
        _dbKey         = "Alpha_Squad",
        inf            = 3,
        mg             = 1,
        at             = 0,
        aa             = 0,
        mortar         = 0,
        jtac           = 0,
        civ            = 0,
        specificParams = {},
    }
    for k, v in pairs(overrides or {}) do t[k] = v end
    return t
end

describe("CTLDTroopManager", function()

    local tm
    local mockUnit
    local _origGs

    before_each(function()
        -- Reset all singletons
        CTLDTroopManager._instance  = nil
        CTLDPlayerManager._instance = nil
        ctld.MenuManager._instance  = nil
        EventDispatcher._instance   = nil
        CTLDZoneManager._instance   = nil
        CTLDJTACManager._instance   = nil
        CTLDVehicleSpawner._instance= nil
        _cmInstance                 = nil

        -- Mock ctld.gs for troop capacity
        _origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { troopsEnabled=true, maxTroopsOnboard=10 } }
            end
            if k == "numberOfTroops"       then return 10 end
            if k == "nbLimitSpawnedTroops" then return { 0, 0 } end
            if k == "maxTransportWeight"   then return 0 end
            if k == "spawnDistanceInCircle" then return 10 end
            if k == "enableFastRopeInsertion" then return false end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "maxExtractDistance"      then return 125 end
            return _origGs(k)
        end

        tm       = CTLDTroopManager.getInstance()
        mockUnit = makeUnit("UH-1H-1")
    end)

    after_each(function()
        ctld.gs = _origGs
    end)

    -- ── F-033 : embarkFromTroopZone ───────────────────────────────
    describe("F-033 — embarkFromTroopZone guards + success", function()

        it("guard: inactive zone → false", function()
            local r = tm:embarkFromTroopZone(mockUnit, makeZone({ active=false }), makeTemplate())
            assert.is_false(r)
        end)

        it("guard: coalition mismatch (zone RED, unit BLUE) → false", function()
            local r = tm:embarkFromTroopZone(mockUnit, makeZone({ coalition=1 }), makeTemplate())
            assert.is_false(r)
        end)

        it("guard: zone outside (isInZone=false) → false", function()
            local z = makeZone({ isInZone = function() return false end })
            local r = tm:embarkFromTroopZone(mockUnit, z, makeTemplate())
            assert.is_false(r)
        end)

        it("guard: template.total > transport limit → false", function()
            local bigTmpl = makeTemplate({ total=20, inf=20 })
            local r = tm:embarkFromTroopZone(mockUnit, makeZone(), bigTmpl)
            assert.is_false(r)
        end)

        it("success: troops loaded → true", function()
            local r = tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            assert.is_true(r)
        end)

        it("success: hasTroops == true after embark", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            assert.is_true(tm:hasTroops("UH-1H-1"))
        end)

        it("success: getInTransit returns list with 1 entry", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            local list = tm:getInTransit("UH-1H-1")
            assert.is_not_nil(list)
            assert.equals(1, #list)
        end)

        it("success: templateName == 'Alpha Squad'", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            local list = tm:getInTransit("UH-1H-1")
            assert.equals("Alpha Squad", list[1].templateName)
        end)

        it("success: unitTotal == 4", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            local list = tm:getInTransit("UH-1H-1")
            assert.equals(4, list[1].unitTotal)
        end)

        it("guard: already at capacity → false on second load", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            -- Second load of same 4-unit group: current=4, limit=10 → still ok
            -- Load a group that fills up the remaining capacity:
            local bigTmpl = makeTemplate({ name="BigSquad", total=7, inf=7 })
            tm:embarkFromTroopZone(mockUnit, makeZone(), bigTmpl)  -- fills to 11 → false
            -- Actually 4+7=11 > 10 → false
            local list = tm:getInTransit("UH-1H-1")
            assert.equals(1, #list)  -- only the first group was loaded
        end)

        it("zone.limit decremented after load (limited zone)", function()
            local zone = makeZone({ pickMaxStock=5, pickCurrentStock=5 })
            tm:embarkFromTroopZone(mockUnit, zone, makeTemplate())
            assert.equals(5 - 4, zone.pickCurrentStock)
        end)

        it("unlimited zone (pickMaxStock=0) stock unchanged", function()
            local zone = makeZone({ pickMaxStock=0, pickCurrentStock=99 })
            tm:embarkFromTroopZone(mockUnit, zone, makeTemplate())
            assert.equals(99, zone.pickCurrentStock)  -- consumeStock no-op for unlimited
        end)

    end)

    -- ── F-034 : disembark on ground ───────────────────────────────
    describe("F-034 — disembark on ground (no EXZ)", function()

        local mockDCSGroup
        local _origSpawn
        local _origGetZm

        before_each(function()
            -- Load a group first
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())

            mockDCSGroup = {
                _name    = "MockDeploy_034",
                getName  = function(self) return self._name end,
                getUnits = function(self) return {} end,
                isExist  = function(self) return true end,
            }

            -- Stub CTLDObjectRegistry.spawnObject
            _origSpawn = CTLDObjectRegistry.spawnObject
            CTLDObjectRegistry.spawnObject = function(key, coa, country, x, z, hdg, opts)
                return mockDCSGroup
            end

            -- Stub CTLDZoneManager to return nil for isUnitInZone (no EXZ, no WPZ)
            local zm = CTLDZoneManager.getInstance()
            _origGetZm = { isUnitInZone = zm.isUnitInZone, getWaypointZoneAt = zm.getWaypointZoneAt }
            zm.isUnitInZone    = function(self, n, t) return nil end
            zm.getWaypointZoneAt = function(self, p, c) return nil end

            -- Force on-ground
            tm._isInAir = function(self, u) return false end
        end)

        after_each(function()
            CTLDObjectRegistry.spawnObject = _origSpawn
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone    = _origGetZm.isUnitInZone
            zm.getWaypointZoneAt = _origGetZm.getWaypointZoneAt
        end)

        it("guard: no troops → false", function()
            local u2 = makeUnit("UH-1H-2")
            local r = tm:disembark(u2)
            assert.is_false(r)
        end)

        it("deploy returns true", function()
            local r = tm:disembark(mockUnit)
            assert.is_true(r)
        end)

        it("hasTroops == false after disembark", function()
            tm:disembark(mockUnit)
            assert.is_false(tm:hasTroops("UH-1H-1"))
        end)

        it("group added to _droppedGroups", function()
            local coa = mockUnit:getCoalition()
            local before = #tm._droppedGroups[coa]
            tm:disembark(mockUnit)
            assert.equals(before + 1, #tm._droppedGroups[coa])
        end)

        it("CTLDObjectRegistry.spawnObject was called", function()
            local called = false
            CTLDObjectRegistry.spawnObject = function(...)
                called = true
                return mockDCSGroup
            end
            tm:disembark(mockUnit)
            assert.is_true(called)
        end)

    end)

    -- ── F-035 : returnToTroopZone ─────────────────────────────────
    describe("F-035 — returnToTroopZone", function()

        it("guard: no troops → false", function()
            local r = tm:returnToTroopZone(mockUnit, makeZone())
            assert.is_false(r)
        end)

        it("after load + return: hasTroops == false", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            tm:returnToTroopZone(mockUnit, makeZone())
            assert.is_false(tm:hasTroops("UH-1H-1"))
        end)

        it("returnToTroopZone returns true", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
            local r = tm:returnToTroopZone(mockUnit, makeZone())
            assert.is_true(r)
        end)

        it("limited zone: stock restored after return", function()
            local zone = makeZone({ pickMaxStock=10, pickCurrentStock=10 })
            tm:embarkFromTroopZone(mockUnit, zone, makeTemplate())
            local stockAfterLoad = zone.pickCurrentStock  -- 10-4=6
            tm:returnToTroopZone(mockUnit, zone)
            assert.equals(stockAfterLoad + 4, zone.pickCurrentStock)  -- 6+4=10
        end)

        it("unlimited zone (pickMaxStock=0) stock unchanged after return", function()
            local zone = makeZone({ pickMaxStock=0, pickCurrentStock=99 })
            tm:embarkFromTroopZone(mockUnit, zone, makeTemplate())
            tm:returnToTroopZone(mockUnit, zone)
            assert.equals(99, zone.pickCurrentStock)
        end)

    end)

    -- ── F-036 : embarkFromField ───────────────────────────────────
    describe("F-036 — embarkFromField (extract)", function()

        local _origGetByName
        local mockGroup

        before_each(function()
            _origGetByName = Group.getByName
            local unitPos = mockUnit:getPoint()
            local mockGroupUnit = {
                _pos     = { x=unitPos.x+10, y=unitPos.y, z=unitPos.z+10 },
                _country = 2,
                getPoint   = function(self) return self._pos end,
                getCountry = function(self) return self._country end,
                getName    = function(self) return "mock_extract_unit" end,
                isExist    = function(self) return true end,
            }
            mockGroup = {
                _name  = "MockDropped_036",
                getName  = function(self) return self._name end,
                getUnits = function(self) return { mockGroupUnit, mockGroupUnit, mockGroupUnit } end,
                getUnit  = function(self, i) return mockGroupUnit end,
                isExist  = function(self) return true end,
                destroy  = function(self) end,
            }
            Group.getByName = function(name)
                if name == "MockDropped_036" then return mockGroup end
                return _origGetByName(name)
            end

            -- Register in droppedGroups
            local coa = mockUnit:getCoalition()
            tm._droppedGroups[coa] = { "MockDropped_036" }
            tm._droppedTemplates["MockDropped_036"] = {
                key    = "Alpha_Squad",
                name   = "Alpha Squad",
                weight = 520,
                total  = 3,
            }

            -- Force on-ground
            tm._isInAir = function(self, u) return false end
        end)

        after_each(function()
            Group.getByName = _origGetByName
        end)

        it("guard: in air → false", function()
            tm._isInAir = function(self, u) return true end
            local r = tm:embarkFromField(mockUnit)
            assert.is_false(r)
        end)

        it("guard: no dropped groups → false", function()
            local coa = mockUnit:getCoalition()
            tm._droppedGroups[coa] = {}
            local r = tm:embarkFromField(mockUnit)
            assert.is_false(r)
        end)

        it("success → true", function()
            local r = tm:embarkFromField(mockUnit)
            assert.is_true(r)
        end)

        it("hasTroops == true after extract", function()
            tm:embarkFromField(mockUnit)
            assert.is_true(tm:hasTroops("UH-1H-1"))
        end)

        it("extracted group has state FIELD_LOADED", function()
            tm:embarkFromField(mockUnit)
            local list = tm:getInTransit("UH-1H-1")
            assert.is_not_nil(list)
            assert.equals(CTLDTroopGroup.STATE.FIELD_LOADED, list[1].state)
        end)

        it("group removed from _droppedGroups after extract", function()
            local coa = mockUnit:getCoalition()
            tm:embarkFromField(mockUnit)
            assert.equals(0, #tm._droppedGroups[coa])
        end)

    end)

end)
