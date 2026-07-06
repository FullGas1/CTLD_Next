---@diagnostic disable
-- tests/unit/crate_manager_spec.lua
-- busted specs for CTLDCrate entity and CTLDCrateManager helpers
-- Reference: live_tests/unit/U-030 through U-034
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDCrate entity", function()

    local pos  = { x = 0, y = 0, z = 0 }
    local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
    local transport

    before_each(function()
        transport = { getName = function() return "heli_test" end }
    end)

    local function makeCrate(overrides)
        local data = {
            crateName   = "test_crate",
            descriptor  = desc,
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = pos,
            coalition   = coalition.side.BLUE,
        }
        if overrides then
            for k, v in pairs(overrides) do data[k] = v end
        end
        return CTLDCrate:new(data)
    end

    -- ── Initial state ─────────────────────────────────────────
    describe("initial state (U-030)", function()

        it("state is SPAWNED after new()", function()
            assert.equals(CTLDCrate.STATE.SPAWNED, makeCrate().state)
        end)

        it("isOnGround() returns true when SPAWNED", function()
            assert.is_true(makeCrate():isOnGround())
        end)

        it("isLoaded() returns false when SPAWNED", function()
            assert.is_false(makeCrate():isLoaded())
        end)

        it("loadedBy is nil after new()", function()
            assert.is_nil(makeCrate().loadedBy)
        end)

        it("canBeUnpacked is true after new()", function()
            assert.is_true(makeCrate().canBeUnpacked)
        end)

    end)

    -- ── State transitions ────────────────────────────────────
    describe("state transitions (U-030)", function()

        it("load() transitions to LOADED", function()
            local c = makeCrate()
            c:load(transport)
            assert.equals(CTLDCrate.STATE.LOADED, c.state)
        end)

        it("load() sets loadedBy", function()
            local c = makeCrate()
            c:load(transport)
            assert.equals(transport, c.loadedBy)
        end)

        it("isLoaded() is true after load()", function()
            local c = makeCrate()
            c:load(transport)
            assert.is_true(c:isLoaded())
        end)

        it("isOnGround() is false when LOADED", function()
            local c = makeCrate()
            c:load(transport)
            assert.is_false(c:isOnGround())
        end)

        it("unload() transitions LOADED → LANDED", function()
            local c = makeCrate()
            c:load(transport)
            c:unload({ x = 100, y = 0, z = 100 })
            assert.equals(CTLDCrate.STATE.LANDED, c.state)
        end)

        it("isOnGround() is true after unload()", function()
            local c = makeCrate()
            c:load(transport)
            c:unload({ x = 100, y = 0, z = 100 })
            assert.is_true(c:isOnGround())
        end)

        it("isLoaded() is false after unload()", function()
            local c = makeCrate()
            c:load(transport)
            c:unload({ x = 100, y = 0, z = 100 })
            assert.is_false(c:isLoaded())
        end)

        it("loadedBy is nil after unload()", function()
            local c = makeCrate()
            c:load(transport)
            c:unload({ x = 100, y = 0, z = 100 })
            assert.is_nil(c.loadedBy)
        end)

        it("loadedBy:isExist() guard — dead unit treated as not loaded", function()
            -- Regression: crate.loadedBy guard must check isExist(), not just nil
            local dead_unit = {
                getName   = function() return "dead_heli" end,
                isExist   = function() return false end,
            }
            local c = makeCrate()
            c:load(dead_unit)
            -- Simulate the guard pattern used in CTLDCrateManager
            local counted = c.loadedBy and c.loadedBy:isExist() and c.loadedBy:getName() or nil
            assert.is_nil(counted)
        end)

        it("drop() transitions LOADED → FALLING", function()
            local c = makeCrate()
            c:load(transport)
            c:drop(pos)
            assert.equals(CTLDCrate.STATE.FALLING, c.state)
        end)

        it("isOnGround() is false when FALLING", function()
            local c = makeCrate()
            c:load(transport)
            c:drop(pos)
            assert.is_false(c:isOnGround())
        end)

        it("land() transitions FALLING → LANDED", function()
            local c = makeCrate()
            c:load(transport)
            c:drop(pos)
            c:land(pos)
            assert.equals(CTLDCrate.STATE.LANDED, c.state)
        end)

        it("unpack() transitions to UNPACKED", function()
            local c = makeCrate()
            c:unpack()
            assert.equals(CTLDCrate.STATE.UNPACKED, c.state)
        end)

        it("isOnGround() is false when UNPACKED", function()
            local c = makeCrate()
            c:unpack()
            assert.is_false(c:isOnGround())
        end)

    end)

    -- ── startParachute ────────────────────────────────────────
    describe("startParachute (U-030)", function()

        it("transitions to FALLING", function()
            local c = makeCrate()
            c:startParachute(500)
            assert.equals(CTLDCrate.STATE.FALLING, c.state)
        end)

    end)

    -- ── destroy ───────────────────────────────────────────────
    describe("destroy (U-030)", function()

        it("does not raise when dcsStatic is nil", function()
            local c = makeCrate()
            assert.has_no_error(function() c:destroy() end)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDCrate canUnpack", function()

    local pos  = { x = 0, y = 0, z = 0 }
    local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }
    local transport = { getName = function() return "heli" end }

    local function makeCrate()
        return CTLDCrate:new({
            crateName   = "c_test",
            descriptor  = desc,
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = pos,
            coalition   = coalition.side.BLUE,
        })
    end

    -- ── Logic guards (U-031) ───────────────────────────────────
    describe("logic guards (U-031)", function()

        it("SPAWNED on ground → canUnpack true", function()
            local c = makeCrate()
            assert.is_true(c:canUnpack())
        end)

        it("canBeUnpacked=false → always false", function()
            local c = makeCrate()
            c.canBeUnpacked = false
            assert.is_false(c:canUnpack())
        end)

        it("LOADED → canUnpack false (not on ground)", function()
            local c = makeCrate()
            c:load(transport)
            assert.is_false(c:canUnpack())
        end)

        it("FALLING → canUnpack false", function()
            local c = makeCrate()
            c:load(transport)
            c:drop(pos)
            assert.is_false(c:canUnpack())
        end)

        it("UNPACKED → canUnpack false", function()
            local c = makeCrate()
            c:unpack()
            assert.is_false(c:canUnpack())
        end)

        it("LANDED → canUnpack true", function()
            local c = makeCrate()
            c:load(transport)
            c:unload(pos)
            assert.is_true(c:canUnpack())
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDCrateManager registry", function()

    local cm

    before_each(function()
        cm = CTLDCrateManager.getInstance()
        cm.crates = {}   -- reset registry between tests
    end)

    local desc = { unit = "M92_Ammo_Pallet", cratesRequired = 1 }

    local function makeCrate(name, xPos)
        return CTLDCrate:new({
            crateName   = name,
            descriptor  = desc,
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = { x = xPos or 0, y = 0, z = 0 },
            coalition   = coalition.side.BLUE,
        })
    end

    -- ── Singleton (U-032) ─────────────────────────────────────
    describe("singleton (U-032)", function()

        it("getInstance() returns a non-nil instance", function()
            assert.is_not_nil(cm)
        end)

        it("getInstance() is idempotent", function()
            assert.equals(cm, CTLDCrateManager.getInstance())
        end)

        it("instance has a crates table", function()
            assert.equals("table", type(cm.crates))
        end)

    end)

    -- ── getCrateByName (U-032) ────────────────────────────────
    describe("getCrateByName (U-032)", function()

        it("returns nil for empty registry", function()
            assert.is_nil(cm:getCrateByName("unknown"))
        end)

        it("returns the correct crate after manual inject", function()
            local c = makeCrate("crate_A", 0)
            cm.crates["crate_A"] = c
            assert.equals(c, cm:getCrateByName("crate_A"))
        end)

        it("returns nil for unknown name after inject", function()
            cm.crates["crate_A"] = makeCrate("crate_A", 0)
            assert.is_nil(cm:getCrateByName("crate_X"))
        end)

    end)

    -- ── getCratesInRange (U-032) ──────────────────────────────
    describe("getCratesInRange (U-032)", function()

        it("returns 2 crates within radius=100", function()
            cm.crates["crate_A"] = makeCrate("crate_A",   0)
            cm.crates["crate_B"] = makeCrate("crate_B",  50)
            cm.crates["crate_C"] = makeCrate("crate_C", 200)
            local result = cm:getCratesInRange({ x=0, y=0, z=0 }, 100)
            assert.equals(2, #result)
        end)

        it("returns all 3 crates within radius=300", function()
            cm.crates["crate_A"] = makeCrate("crate_A",   0)
            cm.crates["crate_B"] = makeCrate("crate_B",  50)
            cm.crates["crate_C"] = makeCrate("crate_C", 200)
            local result = cm:getCratesInRange({ x=0, y=0, z=0 }, 300)
            assert.equals(3, #result)
        end)

        it("excludes LOADED crates from results", function()
            local transport = { getName = function() return "heli" end }
            local c_a = makeCrate("crate_A",  0)
            local c_b = makeCrate("crate_B", 50)
            c_b:load(transport)   -- LOADED → excluded
            cm.crates["crate_A"] = c_a
            cm.crates["crate_B"] = c_b
            local result = cm:getCratesInRange({ x=0, y=0, z=0 }, 100)
            assert.equals(1, #result)
        end)

        it("returns empty table when registry is empty", function()
            local result = cm:getCratesInRange({ x=0, y=0, z=0 }, 1000)
            assert.equals(0, #result)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDCrateManager checkAssemblyReady", function()

    local cm
    local transport = { getName = function() return "heli" end }

    before_each(function()
        cm = CTLDCrateManager.getInstance()
        cm.crates = {}
    end)

    local function makeCrate(name, unitType, xPos, req)
        return CTLDCrate:new({
            crateName   = name,
            descriptor  = { unit = unitType, cratesRequired = req },
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = { x = xPos or 0, y = 0, z = 0 },
            coalition   = coalition.side.BLUE,
        })
    end

    -- ── U-034 ─────────────────────────────────────────────────
    describe("single-crate unit always ready (U-034)", function()

        it("cratesRequired=1 → returns true immediately", function()
            local c = makeCrate("single_A", "M92_Ammo_Pallet", 0, 1)
            cm.crates["single_A"] = c
            local ready, assembled = cm:checkAssemblyReady(c, 100)
            assert.is_true(ready)
            assert.equals(1, #assembled)
            assert.equals(c, assembled[1])
        end)

    end)

    describe("multi-crate unit (U-034)", function()

        it("cratesRequired=2 with 2 crates in range → ready", function()
            local cA = makeCrate("kub_A", "KUB_Launcher", 0,  2)
            local cB = makeCrate("kub_B", "KUB_Launcher", 50, 2)
            cm.crates["kub_A"] = cA
            cm.crates["kub_B"] = cB
            local ready, assembled = cm:checkAssemblyReady(cA, 100)
            assert.is_true(ready)
            assert.equals(2, #assembled)
        end)

        it("cratesRequired=2 with second crate out of range → not ready", function()
            local cC = makeCrate("kub_C", "KUB_Launcher",   0, 2)
            local cD = makeCrate("kub_D", "KUB_Launcher", 200, 2)
            cm.crates["kub_C"] = cC
            cm.crates["kub_D"] = cD
            local ready, assembled = cm:checkAssemblyReady(cC, 100)
            assert.is_false(ready)
            assert.equals(1, #assembled)
        end)

        it("LOADED crate excluded from assembly count", function()
            local cE = makeCrate("nas_E", "NASAMS_Box",  0, 2)
            local cF = makeCrate("nas_F", "NASAMS_Box", 10, 2)
            cF:load(transport)
            cm.crates["nas_E"] = cE
            cm.crates["nas_F"] = cF
            local ready, assembled = cm:checkAssemblyReady(cE, 100)
            assert.is_false(ready)
            assert.equals(1, #assembled)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDCrateManager findDescriptorByUnitType", function()
    -- U-033

    local cm

    before_each(function()
        cm = CTLDCrateManager.getInstance()
        cm.crates = {}
    end)

    it("returns descriptor for a known unit type (M-1 Abrams)", function()
        local d = cm:findDescriptorByUnitType("M-1 Abrams")
        assert.is_not_nil(d)
        assert.equals(4, d.cratesRequired)
    end)

    it("returns descriptor for a multi-crate unit (M1043 cratesRequired=3)", function()
        local d = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
        assert.is_not_nil(d)
        assert.equals(3, d.cratesRequired)
    end)

    it("returns nil for unknown unit type", function()
        assert.is_nil(cm:findDescriptorByUnitType("NonExistentUnit"))
    end)

    it("returns nil for nil input", function()
        assert.is_nil(cm:findDescriptorByUnitType(nil))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDCrateManager spawnCrate", function()
    -- U-083

    local cm
    local spawnedStatics, origAddStatic, origGetByName, origGetAbsTime

    before_each(function()
        cm = CTLDCrateManager.getInstance()
        cm.crates = {}

        spawnedStatics = {}

        origAddStatic  = coalition.addStaticObject
        origGetByName  = StaticObject.getByName
        origGetAbsTime = timer.getAbsTime

        -- Capture addStaticObject calls and return a mock object
        coalition.addStaticObject = function(cId, data)
            spawnedStatics[data.name] = { countryId = cId, data = data }
            return { getName = function() return data.name end }
        end

        -- Return stub when name matches a spawned static
        StaticObject.getByName = function(name)
            return spawnedStatics[name] and { _name = name } or nil
        end

        timer.getAbsTime = function() return 100 end
    end)

    after_each(function()
        coalition.addStaticObject = origAddStatic
        StaticObject.getByName    = origGetByName
        timer.getAbsTime          = origGetAbsTime
    end)

    it("returns a CTLDCrate with correct fields", function()
        local d    = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
        local pos  = { x = 100, y = 10, z = 200 }
        local crate = cm:spawnCrate(d, pos, coalition.side.BLUE, "pilot1", "crate_spawn")
        assert.is_not_nil(crate)
        assert.is_not_nil(crate.crateName)
        assert.equals(coalition.side.BLUE, crate.coalition)
        assert.equals("pilot1",            crate.spawnedBy)
        assert.equals("crate_spawn",       crate.spawnMethod)
        assert.equals(pos,                 crate.position)
    end)

    it("coalition.addStaticObject called with correct position and mass", function()
        local d    = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
        local pos  = { x = 100, y = 10, z = 200 }
        local crate = cm:spawnCrate(d, pos, coalition.side.BLUE, nil, "crate_spawn")
        local sd = crate and spawnedStatics[crate.crateName]
        assert.is_not_nil(sd)
        assert.equals(100,      sd.data.x)
        assert.equals(200,      sd.data.y)   -- DCS y = world z
        assert.equals(d.weight, sd.data.mass)
        assert.equals("Cargos", sd.data.category)
    end)

    it("crate is registered in manager.crates", function()
        local d    = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
        local crate = cm:spawnCrate(d, { x=0, y=0, z=0 }, coalition.side.BLUE, nil, "crate_spawn")
        assert.is_not_nil(crate)
        assert.is_not_nil(cm.crates[crate.crateName])
    end)

    it("publishes OnCrateSpawned event", function()
        local fired = {}
        EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
            table.insert(fired, evt)
        end)
        local d    = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
        local crate = cm:spawnCrate(d, { x=0, y=0, z=0 }, coalition.side.BLUE, nil, "crate_spawn")
        assert.is_not_nil(crate)
        assert.equals(1,               #fired)
        assert.equals(crate.crateName, fired[1].crateName)
    end)

    it("dynamic modelKey sets canCargo=true", function()
        local d    = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
        local crate = cm:spawnCrate(d, { x=0, y=0, z=0 }, coalition.side.RED,
            nil, "vehicle_pack", country.id.RUSSIA, "dynamic")
        assert.is_not_nil(crate)
        local sd = spawnedStatics[crate.crateName]
        assert.is_true(sd.data.canCargo)
    end)

    it("returns nil for nil descriptor", function()
        assert.is_nil(cm:spawnCrate(nil, { x=0, y=0, z=0 }, coalition.side.BLUE, nil, "crate_spawn"))
    end)

end)
