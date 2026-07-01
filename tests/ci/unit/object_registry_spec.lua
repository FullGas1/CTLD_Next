---@diagnostic disable
-- tests/unit/object_registry_spec.lua
-- busted specs for CTLDObjectRegistry: get, findByDCSType, registerIfAbsent, spawnObject
-- Reference: live_tests/unit/U-054 through U-056
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDObjectRegistry get() + findByDCSType()", function()
    -- U-054

    -- ── get() ───────────────────────────────────────────────
    describe("get()", function()

        it("get('FARP') returns a non-nil descriptor", function()
            assert.is_not_nil(CTLDObjectRegistry.get("FARP"))
        end)

        it("FARP descriptor has groupType == 'STATIC'", function()
            assert.equals("STATIC", CTLDObjectRegistry.get("FARP").groupType)
        end)

        it("FARP descriptor has category == 'Heliports'", function()
            assert.equals("Heliports", CTLDObjectRegistry.get("FARP").category)
        end)

        it("get('FARP_Security_Guard') returns a non-nil descriptor", function()
            assert.is_not_nil(CTLDObjectRegistry.get("FARP_Security_Guard"))
        end)

        it("FARP_Security_Guard groupType == 'GROUND'", function()
            assert.equals("GROUND", CTLDObjectRegistry.get("FARP_Security_Guard").groupType)
        end)

        it("FARP_Security_Guard has 3 units", function()
            local desc = CTLDObjectRegistry.get("FARP_Security_Guard")
            assert.equals(3, #desc.units)
        end)

        it("get('nonexistent_key') returns nil", function()
            assert.is_nil(CTLDObjectRegistry.get("nonexistent_key"))
        end)

    end)

    -- ── findByDCSType() ──────────────────────────────────────
    describe("findByDCSType()", function()

        it("findByDCSType('ammo_cargo') returns correct key", function()
            local k, _ = CTLDObjectRegistry.findByDCSType("ammo_cargo")
            assert.equals("ammo_cargo", k)
        end)

        it("findByDCSType('ammo_cargo') returns a descriptor", function()
            local _, d = CTLDObjectRegistry.findByDCSType("ammo_cargo")
            assert.is_not_nil(d)
        end)

        it("findByDCSType('Cargo06') returns correct key", function()
            local k, _ = CTLDObjectRegistry.findByDCSType("Cargo06")
            assert.equals("Cargo06", k)
        end)

        it("findByDCSType(nil) returns nil key and nil desc", function()
            local k, d = CTLDObjectRegistry.findByDCSType(nil)
            assert.is_nil(k)
            assert.is_nil(d)
        end)

        it("findByDCSType('totally_unknown') returns nil key", function()
            local k, _ = CTLDObjectRegistry.findByDCSType("totally_unknown_dcs_type")
            assert.is_nil(k)
        end)

        it("findByDCSType('totally_unknown') returns nil desc", function()
            local _, d = CTLDObjectRegistry.findByDCSType("totally_unknown_dcs_type")
            assert.is_nil(d)
        end)

    end)

    -- ── registerIfAbsent() ────────────────────────────────────
    describe("registerIfAbsent()", function()

        local testKey = "__test_registry_key__"

        after_each(function()
            CTLDObjectRegistry._db[testKey] = nil
        end)

        it("registers a new key and returns true", function()
            local ok = CTLDObjectRegistry.registerIfAbsent(testKey, { groupType = "STATIC", type = "test" })
            assert.is_true(ok)
        end)

        it("registered entry is retrievable via get()", function()
            CTLDObjectRegistry.registerIfAbsent(testKey, { groupType = "STATIC", type = "test_type" })
            assert.is_not_nil(CTLDObjectRegistry.get(testKey))
        end)

        it("second registration of same key returns false", function()
            CTLDObjectRegistry.registerIfAbsent(testKey, { groupType = "STATIC", type = "test" })
            local ok2 = CTLDObjectRegistry.registerIfAbsent(testKey, { groupType = "STATIC", type = "test2" })
            assert.is_false(ok2)
        end)

        it("first registration wins (data not overwritten)", function()
            CTLDObjectRegistry.registerIfAbsent(testKey, { groupType = "STATIC", type = "original" })
            CTLDObjectRegistry.registerIfAbsent(testKey, { groupType = "STATIC", type = "override" })
            assert.equals("original", CTLDObjectRegistry.get(testKey).type)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDObjectRegistry spawnObject() STATIC", function()
    -- U-055

    local staticCalls, origAddStatic

    before_each(function()
        staticCalls = {}
        origAddStatic = coalition.addStaticObject
        coalition.addStaticObject = function(countryId, groupData)
            table.insert(staticCalls, { countryId = countryId, groupData = groupData })
            return { getName = function() return groupData.name end }
        end
    end)

    after_each(function()
        coalition.addStaticObject = origAddStatic
    end)

    it("spawnObject('FARP') returns non-nil", function()
        local result = CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 1000, 2000, 0)
        assert.is_not_nil(result)
    end)

    it("coalition.addStaticObject called once for FARP", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 1000, 2000, 0)
        assert.equals(1, #staticCalls)
    end)

    it("groupData.x matches spawn x", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 1000, 2000, 0)
        assert.equals(1000, staticCalls[1].groupData.x)
    end)

    it("groupData.y matches spawn z (DCS y = world Z)", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 1000, 2000, 0)
        assert.equals(2000, staticCalls[1].groupData.y)
    end)

    it("groupData.heading == 0", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0)
        assert.equals(0, staticCalls[1].groupData.heading)
    end)

    it("groupData.start_time == 0", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0)
        assert.equals(0, staticCalls[1].groupData.start_time)
    end)

    it("groupData.name is injected (non-nil)", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0)
        assert.is_not_nil(staticCalls[1].groupData.name)
    end)

    it("groupData.transportable is injected", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0)
        assert.is_not_nil(staticCalls[1].groupData.transportable)
    end)

    it("groupType is stripped from groupData", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0)
        assert.is_nil(staticCalls[1].groupData.groupType)
    end)

    it("namePrefix is stripped from groupData", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0)
        assert.is_nil(staticCalls[1].groupData.namePrefix)
    end)

    it("descriptor.type preserved in groupData", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0)
        assert.equals("FARP", staticCalls[1].groupData.type)
    end)

    it("unknown key returns nil, no addStaticObject call", function()
        local prevCount = #staticCalls
        local result = CTLDObjectRegistry.spawnObject("__no_such_key__", coalition.side.BLUE, 2, 0, 0, 0)
        assert.is_nil(result)
        assert.equals(prevCount, #staticCalls)
    end)

    it("overrides are merged into groupData", function()
        CTLDObjectRegistry.spawnObject("FARP", coalition.side.BLUE, 2, 0, 0, 0,
            { heliport_frequency = "130.0", custom_field = "yes" })
        local gd = staticCalls[1].groupData
        assert.equals("130.0", gd.heliport_frequency)
        assert.equals("yes",   gd.custom_field)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDObjectRegistry spawnObject() GROUND", function()
    -- U-056

    local groupCalls, origAddGroup

    local function approxEq(a, b, eps)
        return math.abs(a - b) < (eps or 0.001)
    end

    before_each(function()
        groupCalls = {}
        origAddGroup = coalition.addGroup
        coalition.addGroup = function(countryId, category, groupData)
            table.insert(groupCalls, { countryId = countryId, category = category, groupData = groupData })
            return { getName = function() return groupData.name end }
        end
    end)

    after_each(function()
        coalition.addGroup = origAddGroup
    end)

    it("spawnObject('FARP_Security_Guard') returns non-nil", function()
        local result = CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, 0)
        assert.is_not_nil(result)
    end)

    it("coalition.addGroup called once", function()
        CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, 0)
        assert.equals(1, #groupCalls)
    end)

    it("spawned group has 3 units", function()
        CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, 0)
        assert.equals(3, #groupCalls[1].groupData.units)
    end)

    it("BLUE coalition → unit[1].type == 'Soldier M4'", function()
        CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, 0)
        assert.equals("Soldier M4", groupCalls[1].groupData.units[1].type)
    end)

    it("RED coalition → unit[1].type == 'Infantry AK'", function()
        CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.RED, 0, 0, 0, 0)
        assert.equals("Infantry AK", groupCalls[1].groupData.units[1].type)
    end)

    it("heading=0, unit[1] at spawn origin (dx=0, dz=0)", function()
        CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, 0)
        local u1 = groupCalls[1].groupData.units[1]
        assert.is_true(approxEq(u1.x, 0))
        assert.is_true(approxEq(u1.y, 0))
    end)

    it("heading=0, unit[2] at dx=3, dz=1 (no rotation)", function()
        CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, 0)
        local u2 = groupCalls[1].groupData.units[2]
        assert.is_true(approxEq(u2.x, 3))  -- dx=3, cosH=1, sinH=0: ux=3+0=3
        assert.is_true(approxEq(u2.y, 1))  -- dz=1, cosH=1, sinH=0: uz=0+1=1
    end)

    it("heading=pi/2, unit[2] rotated to x=-1, y=3", function()
        -- dx=3, dz=1, heading=pi/2: cosH≈0, sinH≈1
        -- ux = 0 + 3*0 - 1*1 = -1
        -- uz = 0 + 3*1 + 1*0 = 3
        CTLDObjectRegistry.spawnObject("FARP_Security_Guard", coalition.side.BLUE, 2, 0, 0, math.pi / 2)
        local u2 = groupCalls[1].groupData.units[2]
        assert.is_true(approxEq(u2.x, -1))
        assert.is_true(approxEq(u2.y,  3))
    end)

end)
