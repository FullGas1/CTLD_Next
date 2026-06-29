---@diagnostic disable
-- tests/functional/troop_multi_spec.lua
-- busted specs for CTLDTroopManager multi-group features
-- Reference: live_tests/functional/F-140→F-146 (Witchcraft DCS)
-- ============================================================

local function makeUnit(name)
    return {
        _name = name,
        getName      = function(self) return self._name end,
        getCoalition = function(self) return coalition.side.BLUE end,
        getCountry   = function(self) return 2 end,
        getTypeName  = function(self) return "UH-1H" end,
        getPoint     = function(self) return { x=0, y=5, z=0 } end,
        getPosition  = function(self) return { x={x=1,y=0,z=0}, p={x=0,y=5,z=0} } end,
        getVelocity  = function(self) return { x=0, y=0, z=0 } end,
        getGroup     = function(self) return { getID = function() return 9901 end } end,
        isExist      = function(self) return true end,
    }
end

-- Minimal group stub for disembark (CTLDObjectRegistry.spawnObject return value)
local function makeDCSGroup(name)
    return {
        _name   = name or "SpawnedGroup",
        getName = function(self) return self._name end,
        getUnits = function(self) return {} end,
        isExist  = function(self) return true end,
    }
end

-- Build a CTLDTroopGroup-like table for direct injection into _inTransit
local function makeTroopGroup(name, dbKey, total, weight)
    return CTLDTroopGroup:new({
        templateName = name,
        _dbKey       = dbKey or name,
        unitTotal    = total or 4,
        weight       = weight or 520,
        inf          = total or 4,
        mg=0, at=0, aa=0, mortar=0, jtac=0, civ=0,
        specificParams = {},
        coalitionId  = coalition.side.BLUE,
    })
end

-- PlayerObj as expected by refreshMenuSection
local function makePlayerObj(unitName)
    return {
        unitName   = unitName or "UH-1H-1",
        groupId    = 9901,
        typeName   = "UH-1H",
        isTransport = true,
        coalition  = coalition.side.BLUE,
    }
end

describe("CTLDTroopManager — multi-group", function()

    local tm
    local mockUnit
    local playerObj
    local _origGs
    local _origSpawn
    local _origGetByName

    before_each(function()
        -- Reset all singletons
        CTLDTroopManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        ctld.MenuManager._instance   = nil
        EventDispatcher._instance    = nil
        CTLDZoneManager._instance    = nil
        CTLDJTACManager._instance    = nil
        CTLDVehicleSpawner._instance = nil
        _cmInstance                  = nil

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

        tm        = CTLDTroopManager.getInstance()
        mockUnit  = makeUnit("UH-1H-1")
        playerObj = makePlayerObj("UH-1H-1")

        -- Stub spawn so disembark works without DCS
        _origSpawn = CTLDObjectRegistry.spawnObject
        CTLDObjectRegistry.spawnObject = function(...)
            return makeDCSGroup("SpawnedGrp")
        end

        -- Force on-ground
        tm._isInAir = function(self, _) return false end

        -- Stub Zone/ZoneManager so refreshMenuSection doesn't crash
        local zm = CTLDZoneManager.getInstance()
        zm.getTroopZonesForCoalition = function(self, _) return {} end
        zm.isUnitInZone              = function(self, _, _) return nil end
        zm.getWaypointZoneAt         = function(self, _, _) return nil end

        -- Stub nearby dropped groups (none by default)
        tm._findAllNearbyDropped = function(self, _, _) return {} end

        -- Stub Unit.getByName so refreshMenuSection can get the unit
        _origGetByName = Unit.getByName
        Unit.getByName = function(name)
            if name == "UH-1H-1" then return mockUnit end
            return _origGetByName and _origGetByName(name) or nil
        end
    end)

    after_each(function()
        ctld.gs = _origGs
        CTLDObjectRegistry.spawnObject = _origSpawn
        Unit.getByName = _origGetByName
    end)

    -- ── F-140 : refreshMenuSection — single group ─────────────────────────────────
    describe("F-140 — refreshMenuSection single group → direct Disembark command", function()

        it("single group: 'Disembark Troops' command present at troop sub level", function()
            tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha Squad") }
            local pm   = CTLDPlayerManager.getInstance()
            pm:buildMenu(playerObj)
            tm:refreshMenuSection(playerObj)
            local mm   = ctld.MenuManager:getInstance()
            local menu = mm:getMenuByGroupId(playerObj.groupId)
            local node = menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                         ctld.tr("Disembark Troops") })
            assert.is_not_nil(node)
        end)

        it("single group: no 'Disembark Troops' SUBMENU (node has no sub-entries for group names)", function()
            tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha Squad") }
            local pm   = CTLDPlayerManager.getInstance()
            pm:buildMenu(playerObj)
            tm:refreshMenuSection(playerObj)
            local mm   = ctld.MenuManager:getInstance()
            local menu = mm:getMenuByGroupId(playerObj.groupId)
            -- "[1] Alpha Squad" should NOT exist under a Disembark submenu
            local subNode = menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                            ctld.tr("Disembark Troops"), "[1] Alpha Squad" })
            assert.is_nil(subNode)
        end)

    end)

    -- ── F-141 : refreshMenuSection — two groups ───────────────────────────────────
    describe("F-141 — refreshMenuSection two groups → Disembark Troops submenu", function()

        before_each(function()
            tm._inTransit["UH-1H-1"] = {
                makeTroopGroup("Alpha Squad"),
                makeTroopGroup("Bravo Squad"),
            }
            local pm = CTLDPlayerManager.getInstance()
            pm:buildMenu(playerObj)
            tm:refreshMenuSection(playerObj)
        end)

        it("'Disembark All' command present", function()
            local mm   = ctld.MenuManager:getInstance()
            local menu = mm:getMenuByGroupId(playerObj.groupId)
            local node = menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                         ctld.tr("Disembark Troops"), ctld.tr("Disembark All") })
            assert.is_not_nil(node)
        end)

        it("'[1] Alpha Squad' entry present", function()
            local mm   = ctld.MenuManager:getInstance()
            local menu = mm:getMenuByGroupId(playerObj.groupId)
            local node = menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                         ctld.tr("Disembark Troops"), "[1] Alpha Squad" })
            assert.is_not_nil(node)
        end)

        it("'[2] Bravo Squad' entry present", function()
            local mm   = ctld.MenuManager:getInstance()
            local menu = mm:getMenuByGroupId(playerObj.groupId)
            local node = menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                         ctld.tr("Disembark Troops"), "[2] Bravo Squad" })
            assert.is_not_nil(node)
        end)

    end)

    -- ── F-142 : disembarkAll ──────────────────────────────────────────────────────
    describe("F-142 — disembarkAll deploys all groups", function()

        it("returns true", function()
            tm._inTransit["UH-1H-1"] = {
                makeTroopGroup("Alpha Squad"),
                makeTroopGroup("Bravo Squad"),
            }
            -- Stub ZoneManager for disembark
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function(self, _, _) return nil end
            local r = tm:disembarkAll(mockUnit)
            assert.is_true(r)
        end)

        it("hasTroops == false after disembarkAll", function()
            tm._inTransit["UH-1H-1"] = {
                makeTroopGroup("Alpha Squad"),
                makeTroopGroup("Bravo Squad"),
            }
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function(self, _, _) return nil end
            tm:disembarkAll(mockUnit)
            assert.is_false(tm:hasTroops("UH-1H-1"))
        end)

        it("both groups added to _droppedGroups", function()
            tm._inTransit["UH-1H-1"] = {
                makeTroopGroup("Alpha Squad"),
                makeTroopGroup("Bravo Squad"),
            }
            local zm  = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function(self, _, _) return nil end
            local coa    = mockUnit:getCoalition()
            local before = #tm._droppedGroups[coa]
            tm:disembarkAll(mockUnit)
            assert.equals(before + 2, #tm._droppedGroups[coa])
        end)

        it("returns false when no troops onboard", function()
            local r = tm:disembarkAll(makeUnit("UH-1H-empty"))
            assert.is_false(r)
        end)

    end)

    -- ── F-143 : disembarkIndex ────────────────────────────────────────────────────
    describe("F-143 — disembarkIndex(2) deploys group at position 2", function()

        it("deploys the group that was at index 2, leaving group at index 1", function()
            local g1 = makeTroopGroup("Alpha Squad")
            local g2 = makeTroopGroup("Bravo Squad")
            tm._inTransit["UH-1H-1"] = { g1, g2 }
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function(self, _, _) return nil end
            local r = tm:disembarkIndex(mockUnit, 2)
            assert.is_true(r)
        end)

        it("after disembarkIndex(2): still has troops (group 1 remains)", function()
            local g1 = makeTroopGroup("Alpha Squad", "Alpha_Squad", 4, 520)
            local g2 = makeTroopGroup("Bravo Squad", "Bravo_Squad", 3, 390)
            tm._inTransit["UH-1H-1"] = { g1, g2 }
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function(self, _, _) return nil end
            tm:disembarkIndex(mockUnit, 2)
            assert.is_true(tm:hasTroops("UH-1H-1"))
        end)

        it("after disembarkIndex(2): exactly 1 group remains in transit", function()
            local g1 = makeTroopGroup("Alpha Squad", "Alpha_Squad", 4, 520)
            local g2 = makeTroopGroup("Bravo Squad", "Bravo_Squad", 3, 390)
            tm._inTransit["UH-1H-1"] = { g1, g2 }
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function(self, _, _) return nil end
            tm:disembarkIndex(mockUnit, 2)
            local list = tm:getInTransit("UH-1H-1")
            assert.is_not_nil(list)
            assert.equals(1, #list)
        end)

        it("disembarkIndex(idx=1) falls back to disembark()", function()
            local g1 = makeTroopGroup("Alpha Squad")
            tm._inTransit["UH-1H-1"] = { g1 }
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function(self, _, _) return nil end
            local r = tm:disembarkIndex(mockUnit, 1)
            assert.is_true(r)
            assert.is_false(tm:hasTroops("UH-1H-1"))
        end)

    end)

    -- ── F-144 : _menuCheckCargo — single group ────────────────────────────────────
    describe("F-144 — _menuCheckCargo single group message", function()

        it("message sent to group (trigger.action.outTextForGroup called)", function()
            local called = false
            local _origOut = trigger.action.outTextForGroup
            trigger.action.outTextForGroup = function(gid, msg, dur)
                called = true
            end

            tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha Squad", "Alpha_Squad", 4, 520) }
            tm:_menuCheckCargo(mockUnit)

            trigger.action.outTextForGroup = _origOut
            assert.is_true(called)
        end)

        it("single group: message contains template name", function()
            local received = nil
            local _origOut = trigger.action.outTextForGroup
            trigger.action.outTextForGroup = function(gid, msg, dur)
                received = msg
            end

            tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha Squad", "Alpha_Squad", 4, 520) }
            tm:_menuCheckCargo(mockUnit)

            trigger.action.outTextForGroup = _origOut
            assert.is_not_nil(received)
            assert.is_truthy(received:find("Alpha Squad"))
        end)

        it("no troops: message == 'No troops onboard.'", function()
            local received = nil
            local _origOut = trigger.action.outTextForGroup
            trigger.action.outTextForGroup = function(gid, msg, dur) received = msg end

            -- No inTransit
            tm:_menuCheckCargo(mockUnit)

            trigger.action.outTextForGroup = _origOut
            assert.is_not_nil(received)
            assert.is_truthy(received:find("No troops"))
        end)

    end)

    -- ── F-145 : _menuCheckCargo — two groups ──────────────────────────────────────
    describe("F-145 — _menuCheckCargo two groups shows TOTAL line", function()

        it("message contains 'TOTAL:' when 2 groups onboard", function()
            local received = nil
            local _origOut = trigger.action.outTextForGroup
            trigger.action.outTextForGroup = function(gid, msg, dur) received = msg end

            tm._inTransit["UH-1H-1"] = {
                makeTroopGroup("Alpha Squad", "Alpha_Squad", 4, 520),
                makeTroopGroup("Bravo Squad", "Bravo_Squad", 3, 390),
            }
            tm:_menuCheckCargo(mockUnit)

            trigger.action.outTextForGroup = _origOut
            assert.is_not_nil(received)
            assert.is_truthy(received:find("TOTAL"))
        end)

        it("TOTAL troops == 7 (4+3)", function()
            local received = nil
            local _origOut = trigger.action.outTextForGroup
            trigger.action.outTextForGroup = function(gid, msg, dur) received = msg end

            tm._inTransit["UH-1H-1"] = {
                makeTroopGroup("Alpha Squad", "Alpha_Squad", 4, 520),
                makeTroopGroup("Bravo Squad", "Bravo_Squad", 3, 390),
            }
            tm:_menuCheckCargo(mockUnit)

            trigger.action.outTextForGroup = _origOut
            assert.is_truthy(received:find("TOTAL: 7 troops"))
        end)

        it("message contains '[1]' and '[2]' prefixes", function()
            local received = nil
            local _origOut = trigger.action.outTextForGroup
            trigger.action.outTextForGroup = function(gid, msg, dur) received = msg end

            tm._inTransit["UH-1H-1"] = {
                makeTroopGroup("Alpha Squad", "Alpha_Squad", 4, 520),
                makeTroopGroup("Bravo Squad", "Bravo_Squad", 3, 390),
            }
            tm:_menuCheckCargo(mockUnit)

            trigger.action.outTextForGroup = _origOut
            assert.is_truthy(received:find("%[1%]"))
            assert.is_truthy(received:find("%[2%]"))
        end)

    end)

    -- ── F-146 : embarkFromField with troops already onboard ───────────────────────
    describe("F-146 — embarkFromField appends to existing transit list", function()

        local _origGroupGetByName

        before_each(function()
            _origGroupGetByName = Group.getByName

            local unitPos     = mockUnit:getPoint()
            local mockGrpUnit = {
                _pos     = { x=unitPos.x+10, y=unitPos.y, z=unitPos.z+10 },
                _country = 2,
                getPoint   = function(self) return self._pos end,
                getCountry = function(self) return self._country end,
                getName    = function(self) return "f146_drop_unit" end,
                isExist    = function(self) return true end,
            }
            local mockGroup = {
                _name    = "MockDrop_F146",
                getName  = function(self) return self._name end,
                getUnits = function(self) return { mockGrpUnit, mockGrpUnit, mockGrpUnit } end,
                getUnit  = function(self, _) return mockGrpUnit end,
                isExist  = function(self) return true end,
                destroy  = function(self) end,
            }
            Group.getByName = function(name)
                if name == "MockDrop_F146" then return mockGroup end
                return _origGroupGetByName(name)
            end

            local coa = mockUnit:getCoalition()
            tm._droppedGroups[coa] = { "MockDrop_F146" }
            tm._droppedTemplates["MockDrop_F146"] = {
                key    = "Alpha_Squad",
                name   = "Alpha Squad",
                weight = 520,
                total  = 3,
            }
        end)

        after_each(function()
            Group.getByName = _origGroupGetByName
        end)

        it("embarkFromField with 1 group already onboard → 2 groups in transit", function()
            -- Pre-load one group
            tm._inTransit["UH-1H-1"] = { makeTroopGroup("Pre-loaded", "Pre_loaded", 4, 520) }

            local r = tm:embarkFromField(mockUnit)
            assert.is_true(r)

            local list = tm:getInTransit("UH-1H-1")
            assert.is_not_nil(list)
            assert.equals(2, #list)
        end)

        it("extracted group has state FIELD_LOADED", function()
            tm._inTransit["UH-1H-1"] = { makeTroopGroup("Pre-loaded", "Pre_loaded", 4, 520) }

            tm:embarkFromField(mockUnit)

            local list = tm:getInTransit("UH-1H-1")
            -- The last entry is the newly extracted group
            local extracted = list[#list]
            assert.equals(CTLDTroopGroup.STATE.FIELD_LOADED, extracted.state)
        end)

        it("guard: in air → false even when dropped groups exist", function()
            tm._isInAir = function(self, _) return true end
            tm._inTransit["UH-1H-1"] = {}
            local r = tm:embarkFromField(mockUnit)
            assert.is_false(r)
        end)

    end)

end)
