---@diagnostic disable
-- tests/unit/fob_spec.lua
-- busted specs for CTLDFOB entity: isAlive / getIntegrityPercent
-- Reference: live_tests/unit/U-018
-- ============================================================

describe("CTLDFOB isAlive + getIntegrityPercent", function()
    -- U-018

    local function makeObj(alive)
        return {
            isExist = function() return alive end,
            getName = function() return "stub" end,
        }
    end

    local function makeFOB(objects)
        return CTLDFOB:new({
            fobId        = "fob_test",
            name         = "Test FOB",
            coalitionId  = coalition.side.BLUE,
            countryId    = 2,
            position     = { x = 0, y = 0, z = 0 },
            sceneObjects = objects,
        })
    end

    -- ── isAlive ─────────────────────────────────────────────
    describe("isAlive()", function()

        it("no scene objects → isAlive false", function()
            assert.is_false(makeFOB({}):isAlive())
        end)

        it("all alive (3/3) → isAlive true", function()
            assert.is_true(makeFOB({ makeObj(true), makeObj(true), makeObj(true) }):isAlive())
        end)

        it("1 alive out of 3 → isAlive true", function()
            assert.is_true(makeFOB({ makeObj(false), makeObj(false), makeObj(true) }):isAlive())
        end)

        it("all dead (0/3) → isAlive false", function()
            assert.is_false(makeFOB({ makeObj(false), makeObj(false), makeObj(false) }):isAlive())
        end)

    end)

    -- ── getIntegrityPercent ──────────────────────────────────
    describe("getIntegrityPercent()", function()

        it("0 objects → integrity 0", function()
            assert.equals(0, makeFOB({}):getIntegrityPercent())
        end)

        it("3/3 alive → integrity 1.0", function()
            assert.equals(1.0, makeFOB({ makeObj(true), makeObj(true), makeObj(true) }):getIntegrityPercent())
        end)

        it("0/3 alive → integrity 0", function()
            assert.equals(0, makeFOB({ makeObj(false), makeObj(false), makeObj(false) }):getIntegrityPercent())
        end)

        it("1/3 alive → integrity ≈ 0.333", function()
            local v = makeFOB({ makeObj(false), makeObj(false), makeObj(true) }):getIntegrityPercent()
            assert.is_true(math.abs(v - 1/3) < 0.001)
        end)

        it("2/4 alive → integrity 0.5", function()
            local v = makeFOB({ makeObj(true), makeObj(false), makeObj(true), makeObj(false) }):getIntegrityPercent()
            assert.equals(0.5, v)
        end)

    end)

end)
