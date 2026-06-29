---@diagnostic disable
-- tests/unit/vehicle_spec.lua
-- busted specs for CTLDVehicle entity states and CTLDVehicleSpawner singleton
-- Reference: live_tests/unit/U-019 through U-020
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDVehicle states", function()
    -- U-019

    local spawnData = {
        groupName   = "CTLD_VEH_HMMWV_veh_1",
        unitName    = "CTLD_VEH_HMMWV_unit_1",
        vehicleType = "M1045 HMMWV TOW",
        countryId   = 2,
        coalitionId = coalition.side.BLUE,
    }

    local veh

    before_each(function()
        veh = CTLDVehicle:new({
            id          = "veh_1",
            vehicleType = "M1045 HMMWV TOW",
            spawnData   = spawnData,
        })
    end)

    -- ── Initial state ────────────────────────────────────────
    describe("initial state", function()

        it("new() returns a non-nil instance", function()
            assert.is_not_nil(veh)
        end)

        it("initial state is WAITING", function()
            assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())
        end)

        it("id is preserved", function()
            assert.equals("veh_1", veh.id)
        end)

        it("vehicleType is preserved", function()
            assert.equals("M1045 HMMWV TOW", veh.vehicleType)
        end)

        it("spawnData is preserved", function()
            assert.equals(spawnData.groupName, veh.spawnData.groupName)
        end)

    end)

    -- ── State transitions ────────────────────────────────────
    describe("state transitions", function()

        it("setState(LOADED) → getState() == LOADED", function()
            veh:setState(CTLDVehicle.STATE.LOADED)
            assert.equals(CTLDVehicle.STATE.LOADED, veh:getState())
        end)

        it("setState(DELIVERED) → getState() == DELIVERED", function()
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh:setState(CTLDVehicle.STATE.DELIVERED)
            assert.equals(CTLDVehicle.STATE.DELIVERED, veh:getState())
        end)

    end)

    -- ── STATE constants ──────────────────────────────────────
    describe("STATE constants", function()

        it("STATE.WAITING == 'WAITING'", function()
            assert.equals("WAITING",   CTLDVehicle.STATE.WAITING)
        end)

        it("STATE.LOADED == 'LOADED'", function()
            assert.equals("LOADED",    CTLDVehicle.STATE.LOADED)
        end)

        it("STATE.DELIVERED == 'DELIVERED'", function()
            assert.equals("DELIVERED", CTLDVehicle.STATE.DELIVERED)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDVehicleSpawner singleton", function()
    -- U-020

    before_each(function()
        CTLDVehicleSpawner._instance = nil
    end)

    it("getInstance() does not throw", function()
        assert.has_no_error(function() CTLDVehicleSpawner.getInstance() end)
    end)

    it("getInstance() is idempotent", function()
        local s1 = CTLDVehicleSpawner.getInstance()
        local s2 = CTLDVehicleSpawner.getInstance()
        assert.equals(s1, s2)
    end)

    it("instance has _vehicles table", function()
        assert.equals("table", type(CTLDVehicleSpawner.getInstance()._vehicles))
    end)

    it("instance has _unitToVehicle table", function()
        assert.equals("table", type(CTLDVehicleSpawner.getInstance()._unitToVehicle))
    end)

    it("_vehicleCount starts at 0", function()
        assert.equals(0, CTLDVehicleSpawner.getInstance()._vehicleCount)
    end)

end)
