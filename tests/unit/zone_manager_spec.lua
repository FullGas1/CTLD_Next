---@diagnostic disable
-- tests/unit/zone_manager_spec.lua
-- busted specs for CTLDZoneManager._parseTRZ/_parseLGZ and CTLDTroopZone/CTLDLogisticZone
-- Reference: live_tests/unit/U-008 through U-013
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDZoneManager._parseTRZ", function()

    local zm

    before_each(function()
        zm = setmetatable({}, CTLDZoneManager)
    end)

    -- ── Valid formats ─────────────────────────────────────────
    describe("valid formats", function()

        it("parses limited-pickup zone TRZ_alpha_B_10_nil_0", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_B_10_nil_0")
            assert.is_not_nil(r)
            assert.is_nil(e)
            assert.equals("alpha", r.zoneName)
            assert.equals(coalition.side.BLUE, r.coalition)
            assert.equals(10, r.pickMaxStock)
            assert.is_nil(r.objectiveFlag)
            assert.is_nil(r.objectiveTarget)
        end)

        it("parses unlimited-pickup zone TRZ_bravo_A_999_nil_0", function()
            local r, e = zm:_parseTRZ("TRZ_bravo_A_999_nil_0")
            assert.is_not_nil(r)
            assert.is_nil(e)
            assert.equals("bravo", r.zoneName)
            assert.equals(0, r.coalition)        -- A = all
            assert.equals(0, r.pickMaxStock)     -- unlimited stored as 0 internally
            assert.is_nil(r.objectiveFlag)
            assert.is_nil(r.objectiveTarget)
        end)

        it("parses extract-only zone TRZ_charlie_R_0_obj1_0", function()
            local r, e = zm:_parseTRZ("TRZ_charlie_R_0_obj1_0")
            assert.is_not_nil(r)
            assert.is_nil(e)
            assert.equals("charlie", r.zoneName)
            assert.equals(coalition.side.RED, r.coalition)
            assert.is_nil(r.pickMaxStock)        -- stock=0 → no pickup
            assert.equals("obj1", r.objectiveFlag)
            assert.is_nil(r.objectiveTarget)     -- target=0 → no win condition
        end)

        it("parses zone with objective target TRZ_delta_B_0_win_50", function()
            local r, e = zm:_parseTRZ("TRZ_delta_B_0_win_50")
            assert.is_not_nil(r)
            assert.is_nil(e)
            assert.equals("delta", r.zoneName)
            assert.equals(coalition.side.BLUE, r.coalition)
            assert.is_nil(r.pickMaxStock)
            assert.equals("win", r.objectiveFlag)
            assert.equals(50, r.objectiveTarget)
        end)

        it("parses mixed pickup+extract zone TRZ_echo_N_20_rescue_100", function()
            local r, e = zm:_parseTRZ("TRZ_echo_N_20_rescue_100")
            assert.is_not_nil(r)
            assert.is_nil(e)
            assert.equals("echo", r.zoneName)
            assert.equals(coalition.side.NEUTRAL, r.coalition)
            assert.equals(20, r.pickMaxStock)
            assert.equals("rescue", r.objectiveFlag)
            assert.equals(100, r.objectiveTarget)
        end)

        it("parses coalition-all zone TRZ_foxtrot_A_5_nil_0", function()
            local r, e = zm:_parseTRZ("TRZ_foxtrot_A_5_nil_0")
            assert.is_not_nil(r)
            assert.is_nil(e)
            assert.equals(0, r.coalition)
            assert.equals(5, r.pickMaxStock)
            assert.is_nil(r.objectiveFlag)
        end)

    end)

    -- ── Invalid formats ───────────────────────────────────────
    describe("invalid formats", function()

        it("rejects wrong prefix LGZ_...", function()
            local r, e = zm:_parseTRZ("LGZ_alpha_B_10_nil_0")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("not a TRZ"))
        end)

        it("rejects empty string", function()
            local r, _ = zm:_parseTRZ("")
            assert.is_nil(r)
        end)

        it("rejects string without TRZ prefix", function()
            local r, _ = zm:_parseTRZ("alpha_B_10_nil_0")
            assert.is_nil(r)
        end)

        it("rejects bare 'TRZ' (missing zoneName)", function()
            local r, e = zm:_parseTRZ("TRZ")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("zoneName"))
        end)

        it("rejects 'TRZ_' (empty zoneName)", function()
            local r, _ = zm:_parseTRZ("TRZ_")
            assert.is_nil(r)
        end)

        it("rejects reserved zoneName 'nil'", function()
            local r, e = zm:_parseTRZ("TRZ_nil_B_10_nil_0")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("reserved"))
        end)

        it("rejects reserved zoneName 'A'", function()
            local r, e = zm:_parseTRZ("TRZ_A_B_10_nil_0")
            assert.is_nil(r)
            assert.is_not_nil(e)
        end)

        it("rejects missing coalition (TRZ_alpha)", function()
            local r, e = zm:_parseTRZ("TRZ_alpha")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("coalition"))
        end)

        it("rejects invalid coalition 'X'", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_X_10_nil_0")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("coalition"))
        end)

        it("rejects missing stock (TRZ_alpha_B)", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_B")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("stock"))
        end)

        it("rejects out-of-range stock 1000", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_B_1000_nil_0")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("stock"))
        end)

        it("rejects negative stock -5", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_B_-5_nil_0")
            assert.is_nil(r)
            assert.is_not_nil(e)
        end)

        it("rejects numeric flag", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_B_10_42_0")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("string"))
        end)

        it("rejects missing target (4 fields)", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_B_10_nil")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("target"))
        end)

        it("rejects negative target -1", function()
            local r, e = zm:_parseTRZ("TRZ_alpha_B_10_nil_-1")
            assert.is_nil(r)
            assert.is_not_nil(e)
            assert.is_not_nil(e:find("target"))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDZoneManager._parseLGZ", function()

    local zm

    before_each(function()
        zm = setmetatable({}, CTLDZoneManager)
    end)

    -- ── Valid formats ─────────────────────────────────────────
    describe("valid formats", function()

        it("parses minimal LGZ_base (no coalition)", function()
            local r = zm:_parseLGZ("LGZ_base")
            assert.is_not_nil(r)
            assert.equals("base", r.name)
            assert.equals(0, r.coalition)
        end)

        it("parses LGZ_farp_B (BLUE)", function()
            local r = zm:_parseLGZ("LGZ_farp_B")
            assert.is_not_nil(r)
            assert.equals("farp", r.name)
            assert.equals(coalition.side.BLUE, r.coalition)
        end)

        it("parses LGZ_depot_R (RED)", function()
            local r = zm:_parseLGZ("LGZ_depot_R")
            assert.is_not_nil(r)
            assert.equals(coalition.side.RED, r.coalition)
        end)

        it("parses LGZ_supply_N (NEUTRAL)", function()
            local r = zm:_parseLGZ("LGZ_supply_N")
            assert.is_not_nil(r)
            assert.equals(coalition.side.NEUTRAL, r.coalition)
        end)

    end)

    -- ── Invalid formats ───────────────────────────────────────
    describe("invalid formats", function()

        it("rejects TRZ_... prefix", function()
            assert.is_nil(zm:_parseLGZ("TRZ_alpha_B"))
        end)

        it("rejects WPZ_... prefix", function()
            assert.is_nil(zm:_parseLGZ("WPZ_x"))
        end)

        it("rejects empty string", function()
            assert.is_nil(zm:_parseLGZ(""))
        end)

        it("does not raise for LGZ_ (empty name)", function()
            assert.has_no_error(function() zm:_parseLGZ("LGZ_") end)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDTroopZone", function()

    local center = {x=1000, y=0, z=2000}

    -- ── isInZone (circular) ───────────────────────────────────
    describe("isInZone (circular)", function()

        local zone

        before_each(function()
            zone = CTLDTroopZone:new({
                dcsName="TRZ_test_B", zoneName="test",
                coalition=2, center=center, radius=500,
            })
        end)

        it("center point is inside", function()
            assert.is_true(zone:isInZone({x=1000,y=0,z=2000}))
        end)

        it("point at 400 m is inside", function()
            assert.is_true(zone:isInZone({x=1400,y=0,z=2000}))
        end)

        it("point exactly on edge (500 m) is inside", function()
            assert.is_true(zone:isInZone({x=1500,y=0,z=2000}))
        end)

        it("point at 501 m is outside", function()
            assert.is_false(zone:isInZone({x=1501,y=0,z=2000}))
        end)

        it("point at 1000 m is outside", function()
            assert.is_false(zone:isInZone({x=2000,y=0,z=2000}))
        end)

        it("diagonal point at ~424 m is inside", function()
            -- sqrt(300^2+300^2) ≈ 424 m < 500 m
            assert.is_true(zone:isInZone({x=1300,y=0,z=2300}))
        end)

        it("diagonal point at ~566 m is outside", function()
            -- sqrt(400^2+400^2) ≈ 566 m > 500 m
            assert.is_false(zone:isInZone({x=1400,y=0,z=2400}))
        end)

    end)

    -- ── Stock management ──────────────────────────────────────
    describe("consumeStock / restoreStock", function()

        it("limited zone starts at pickMaxStock", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_limited_B", zoneName="limited",
                coalition=2, center=center, radius=300, pickMaxStock=10,
            })
            assert.equals(10, z.pickCurrentStock)
        end)

        it("consumeStock(3) reduces stock and returns true", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_limited_B", zoneName="limited",
                coalition=2, center=center, radius=300, pickMaxStock=10,
            })
            assert.is_true(z:consumeStock(3))
            assert.equals(7, z.pickCurrentStock)
        end)

        it("consumeStock exact remainder empties stock", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_limited_B", zoneName="limited",
                coalition=2, center=center, radius=300, pickMaxStock=10,
            })
            z:consumeStock(10)
            assert.equals(0, z.pickCurrentStock)
        end)

        it("consumeStock on empty stock returns false", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_limited_B", zoneName="limited",
                coalition=2, center=center, radius=300, pickMaxStock=10,
            })
            z:consumeStock(10)
            assert.is_false(z:consumeStock(1))
            assert.equals(0, z.pickCurrentStock)
        end)

        it("restoreStock adds back stock", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_limited_B", zoneName="limited",
                coalition=2, center=center, radius=300, pickMaxStock=10,
            })
            z:consumeStock(10)
            z:restoreStock(5)
            assert.equals(5, z.pickCurrentStock)
        end)

        it("restoreStock is capped at pickMaxStock", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_limited_B", zoneName="limited",
                coalition=2, center=center, radius=300, pickMaxStock=10,
            })
            z:consumeStock(10)
            z:restoreStock(20)
            assert.equals(10, z.pickCurrentStock)
        end)

        it("unlimited zone (pickMaxStock=0) always returns true on consume", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_unlimited_B", zoneName="unlimited",
                coalition=2, center=center, radius=300, pickMaxStock=0,
            })
            assert.is_true(z:consumeStock(100))
            assert.is_true(z:consumeStock(1))
            assert.equals(0, z.pickCurrentStock)
        end)

        it("unlimited zone restoreStock does not raise", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_unlimited_B", zoneName="unlimited",
                coalition=2, center=center, radius=300, pickMaxStock=0,
            })
            assert.has_no_error(function() z:restoreStock(5) end)
        end)

        it("zone without pickup returns false on consume", function()
            local z = CTLDTroopZone:new({
                dcsName="TRZ_nopickup", zoneName="nopickup",
                coalition=0, center=center, radius=300,
            })
            assert.is_false(z:hasPickup())
            assert.is_false(z:consumeStock(1))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDLogisticZone (static)", function()

    local center = {x=5000, y=0, z=3000}
    local lgz

    before_each(function()
        lgz = CTLDLogisticZone:new({
            name="testLGZ", coalition=2,
            center=center, radius=200, active=true,
        })
    end)

    it("getCenter returns the provided center", function()
        local c = lgz:getCenter()
        assert.is_not_nil(c)
        assert.equals(5000, c.x)
        assert.equals(3000, c.z)
    end)

    it("isAlive returns true for static zone (no linkedUnit)", function()
        assert.is_true(lgz:isAlive())
    end)

    it("isDynamic returns false for static zone", function()
        assert.is_false(lgz:isDynamic())
    end)

    it("point at 100 m is inside", function()
        assert.is_true(lgz:isInZone({x=5100,y=0,z=3000}))
    end)

    it("point exactly on edge (200 m) is inside", function()
        assert.is_true(lgz:isInZone({x=5200,y=0,z=3000}))
    end)

    it("point at 201 m is outside", function()
        assert.is_false(lgz:isInZone({x=5201,y=0,z=3000}))
    end)

    it("default cratesPickup service is true", function()
        assert.is_true(lgz.services.cratesPickup)
    end)

    it("default vehicleSpawn service is true", function()
        assert.is_true(lgz.services.vehicleSpawn)
    end)

end)
