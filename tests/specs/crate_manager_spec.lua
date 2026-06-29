---@diagnostic disable
-- tests/specs/crate_manager_spec.lua
-- busted specs for CTLDCrateManager: findDescriptorByUnitType + spawnCrate
-- Run with: busted tests/specs/crate_manager_spec.lua
-- ============================================================

describe("CTLDCrateManager", function()

    local cm

    -- ── Reset singleton before each test ──────────────────────
    before_each(function()
        CTLDCrateManager._instance = nil
        cm = CTLDCrateManager.getInstance()
    end)

    -- ─────────────────────────────────────────────────────────
    describe("findDescriptorByUnitType", function()

        it("returns descriptor for a known unit type", function()
            local d = cm:findDescriptorByUnitType("M-1 Abrams")
            assert.is_not_nil(d)
            assert.equals(4, d.cratesRequired)
        end)

        it("returns descriptor for a single-crate unit (cratesRequired nil)", function()
            local d = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
            assert.is_not_nil(d)
            assert.is_nil(d.cratesRequired)
        end)

        it("returns nil for an unknown unit type", function()
            local d = cm:findDescriptorByUnitType("NonExistentUnit")
            assert.is_nil(d)
        end)

        it("returns nil for nil input", function()
            local d = cm:findDescriptorByUnitType(nil)
            assert.is_nil(d)
        end)

    end)

    -- ─────────────────────────────────────────────────────────
    describe("spawnCrate", function()

        local _spawnedStatics
        local _origAddStatic
        local _origGetByName
        local _origGetAbsTime

        before_each(function()
            _spawnedStatics = {}

            -- Capture coalition.addStaticObject calls (called internally by dynAddStatic)
            _origAddStatic = coalition.addStaticObject
            coalition.addStaticObject = function(cId, data)
                _spawnedStatics[data.name] = { countryId = cId, data = data }
            end

            _origGetByName = StaticObject.getByName
            StaticObject.getByName = function(name)
                return _spawnedStatics[name] and { _name = name } or nil
            end

            _origGetAbsTime = timer.getAbsTime
            timer.getAbsTime = function() return 100 end
        end)

        after_each(function()
            coalition.addStaticObject = _origAddStatic
            StaticObject.getByName    = _origGetByName
            timer.getAbsTime          = _origGetAbsTime
        end)

        it("returns a CTLDCrate with correct fields", function()
            local d   = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
            local pos = { x = 100, y = 10, z = 200 }
            local crate = cm:spawnCrate(d, pos, coalition.side.BLUE, "pilot1", "crate_spawn")

            assert.is_not_nil(crate)
            assert.is_not_nil(crate.crateName)
            assert.equals(coalition.side.BLUE, crate.coalition)
            assert.equals("pilot1",            crate.spawnedBy)
            assert.equals("crate_spawn",       crate.spawnMethod)
            assert.equals(pos,                 crate.position)
        end)

        it("calls coalition.addStaticObject with correct position and mass", function()
            local d   = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
            local pos = { x = 100, y = 10, z = 200 }
            local crate = cm:spawnCrate(d, pos, coalition.side.BLUE, nil, "crate_spawn")

            local sd = _spawnedStatics[crate.crateName]
            assert.is_not_nil(sd)
            assert.equals(100,      sd.data.x)
            assert.equals(200,      sd.data.y)     -- DCS y = world z
            assert.equals(d.weight, sd.data.mass)
            assert.equals("Cargos", sd.data.category)
        end)

        it("registers the crate in the manager", function()
            local d   = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
            local crate = cm:spawnCrate(d, { x=0, y=0, z=0 }, coalition.side.BLUE, nil, "crate_spawn")
            assert.is_not_nil(cm.crates[crate.crateName])
        end)

        it("publishes OnCrateSpawned event", function()
            local fired = {}
            EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
                table.insert(fired, evt)
            end)

            local d = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
            local crate = cm:spawnCrate(d, { x=0, y=0, z=0 }, coalition.side.BLUE, nil, "crate_spawn")

            assert.equals(1,               #fired)
            assert.equals(crate.crateName, fired[1].crateName)
        end)

        it("sets canCargo=true for dynamic model key", function()
            local d = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
            local crate = cm:spawnCrate(d, { x=0, y=0, z=0 }, coalition.side.RED,
                nil, "vehicle_pack", country.id.RUSSIA, "dynamic")

            local sd = _spawnedStatics[crate.crateName]
            assert.is_true(sd.data.canCargo)
        end)

        it("returns nil for nil descriptor", function()
            local result = cm:spawnCrate(nil, { x=0, y=0, z=0 }, coalition.side.BLUE, nil, "crate_spawn")
            assert.is_nil(result)
        end)

    end)

end)
