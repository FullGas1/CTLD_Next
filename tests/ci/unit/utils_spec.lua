---@diagnostic disable
-- tests/unit/utils_spec.lua
-- busted specs for ctld.utils: math, vectors, table helpers, zoneToVec3
-- Reference: live_tests/unit/U-067 through U-073
-- ============================================================

local function approxEq(a, b, eps)
    return math.abs(a - b) < (eps or 1e-6)
end

-- ─────────────────────────────────────────────────────────────
describe("ctld.utils", function()

    -- ── round ────────────────────────────────────────────────
    describe("round", function()

        it("rounds to 2 decimal places", function()
            assert.is_true(approxEq(ctld.utils.round("t", 3.456, 2), 3.46))
        end)

        it("rounds to 0 decimal places", function()
            assert.is_true(approxEq(ctld.utils.round("t", 3.5, 0), 4))
        end)

        it("rounds negative number toward zero", function()
            assert.is_true(approxEq(ctld.utils.round("t", -2.5, 0), -2))
        end)

        it("returns 0 for nil input", function()
            assert.equals(0, ctld.utils.round("t", nil))
        end)

    end)

    -- ── radianToDegree ───────────────────────────────────────
    describe("radianToDegree", function()

        it("converts π to 180°", function()
            assert.is_true(approxEq(ctld.utils.radianToDegree("t", math.pi), 180))
        end)

        it("converts π/2 to 90°", function()
            assert.is_true(approxEq(ctld.utils.radianToDegree("t", math.pi / 2), 90))
        end)

        it("returns 0 for nil input", function()
            assert.equals(0, ctld.utils.radianToDegree("t", nil))
        end)

    end)

    -- ── normalizeHeadingInDegrees ────────────────────────────
    describe("normalizeHeadingInDegrees", function()

        it("wraps 370° to 10°", function()
            assert.is_true(approxEq(ctld.utils.normalizeHeadingInDegrees("t", 370), 10))
        end)

        it("wraps -90° to 270°", function()
            assert.is_true(approxEq(ctld.utils.normalizeHeadingInDegrees("t", -90), 270))
        end)

        it("wraps 360° to 0°", function()
            assert.is_true(approxEq(ctld.utils.normalizeHeadingInDegrees("t", 360), 0))
        end)

        it("returns 0 for nil input", function()
            assert.equals(0, ctld.utils.normalizeHeadingInDegrees("t", nil))
        end)

    end)

    -- ── kmphToMps ────────────────────────────────────────────
    describe("kmphToMps", function()

        it("converts 360 km/h to 100 m/s", function()
            assert.is_true(approxEq(ctld.utils.kmphToMps("t", 360), 100))
        end)

        it("converts 0 to 0", function()
            assert.is_true(approxEq(ctld.utils.kmphToMps("t", 0), 0))
        end)

        it("returns 0 for nil input", function()
            assert.equals(0, ctld.utils.kmphToMps("t", nil))
        end)

    end)

    -- ── vec3Mag ──────────────────────────────────────────────
    describe("vec3Mag", function()

        it("computes 3-4-5 triangle magnitude", function()
            assert.is_true(approxEq(ctld.utils.vec3Mag("t", {x=3, y=4, z=0}), 5))
        end)

        it("returns 0 for zero vector", function()
            assert.is_true(approxEq(ctld.utils.vec3Mag("t", {x=0, y=0, z=0}), 0))
        end)

        it("computes unit-diagonal magnitude √3", function()
            assert.is_true(approxEq(ctld.utils.vec3Mag("t", {x=1, y=1, z=1}), math.sqrt(3)))
        end)

        it("returns 0 for nil vector", function()
            assert.equals(0, ctld.utils.vec3Mag("t", nil))
        end)

        it("returns 0 when a component is nil", function()
            assert.equals(0, ctld.utils.vec3Mag("t", {x=1, y=nil, z=1}))
        end)

    end)

    -- ── get2DDist ────────────────────────────────────────────
    describe("get2DDist", function()

        it("computes 2D 3-4-5 distance between Vec3 points", function()
            assert.is_true(approxEq(
                ctld.utils.get2DDist("t", {x=0,y=999,z=0}, {x=3,y=999,z=4}), 5))
        end)

        it("computes 2D distance with Vec2 input", function()
            assert.is_true(approxEq(
                ctld.utils.get2DDist("t", {x=0,y=0}, {x=3,y=4}), 5))
        end)

        it("returns 0 when first point is nil", function()
            assert.equals(0, ctld.utils.get2DDist("t", nil, {x=0,z=0}))
        end)

    end)

    -- ── getDistance ──────────────────────────────────────────
    describe("getDistance", function()

        it("computes XZ 3-4-5 distance", function()
            assert.is_true(approxEq(
                ctld.utils.getDistance("t", {x=0,z=0}, {x=3,z=4}), 5))
        end)

        it("returns 0 for same point", function()
            assert.is_true(approxEq(
                ctld.utils.getDistance("t", {x=1,z=1}, {x=1,z=1}), 0))
        end)

        it("returns 0 when first point is nil", function()
            assert.equals(0, ctld.utils.getDistance("t", nil, {x=0,z=0}))
        end)

    end)

    -- ── addVec3 ──────────────────────────────────────────────
    describe("addVec3", function()

        it("adds two vectors component-wise", function()
            local r = ctld.utils.addVec3({x=1,y=2,z=3}, {x=4,y=5,z=6})
            assert.equals(5, r.x)
            assert.equals(7, r.y)
            assert.equals(9, r.z)
        end)

        it("treats nil fields as 0", function()
            local r = ctld.utils.addVec3({x=1}, {z=3})
            assert.equals(1, r.x)
            assert.equals(3, r.z)
        end)

    end)

    -- ── subVec3 ──────────────────────────────────────────────
    describe("subVec3", function()

        it("subtracts two vectors component-wise", function()
            local r = ctld.utils.subVec3("t", {x=5,y=5,z=5}, {x=1,y=2,z=3})
            assert.equals(4, r.x)
            assert.equals(3, r.y)
            assert.equals(2, r.z)
        end)

        it("returns nil when first operand is nil", function()
            assert.is_nil(ctld.utils.subVec3("t", nil, {x=0,y=0,z=0}))
        end)

    end)

    -- ── multVec3 (dot product) ────────────────────────────────
    describe("multVec3", function()

        it("dot product of parallel unit vectors is 1", function()
            assert.equals(1, ctld.utils.multVec3("t", {x=1,y=0,z=0}, {x=1,y=0,z=0}))
        end)

        it("dot product of orthogonal vectors is 0", function()
            assert.equals(0, ctld.utils.multVec3("t", {x=1,y=0,z=0}, {x=0,y=1,z=0}))
        end)

        it("dot product (2,3,4)·(5,6,7) == 56", function()
            assert.equals(56, ctld.utils.multVec3("t", {x=2,y=3,z=4}, {x=5,y=6,z=7}))
        end)

        it("returns 0 when first operand is nil", function()
            assert.equals(0, ctld.utils.multVec3("t", nil, {x=1,y=0,z=0}))
        end)

    end)

    -- ── makeVec3FromVec2OrVec3 ────────────────────────────────
    describe("makeVec3FromVec2OrVec3", function()

        it("converts Vec2 {x,y} to Vec3: y→z, y=0", function()
            local r = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=4})
            assert.equals(1, r.x)
            assert.equals(4, r.z)
            assert.equals(0, r.y)
        end)

        it("uses alt field as y when present", function()
            local r = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=4, alt=100})
            assert.equals(100, r.y)
        end)

        it("uses y parameter over alt", function()
            local r = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=4}, 50)
            assert.equals(50, r.y)
        end)

        it("passes through Vec3 unchanged", function()
            local r = ctld.utils.makeVec3FromVec2OrVec3("t", {x=1, y=2, z=3})
            assert.equals(1, r.x)
            assert.equals(2, r.y)
            assert.equals(3, r.z)
        end)

        it("returns nil for nil input", function()
            assert.is_nil(ctld.utils.makeVec3FromVec2OrVec3("t", nil))
        end)

    end)

    -- ── makeVec2FromVec3OrVec2 ────────────────────────────────
    describe("makeVec2FromVec3OrVec2", function()

        it("converts Vec3 to Vec2: z→y", function()
            local r = ctld.utils.makeVec2FromVec3OrVec2("t", {x=5, y=10, z=20})
            assert.equals(5,  r.x)
            assert.equals(20, r.y)
        end)

        it("passes through Vec2 unchanged", function()
            local r = ctld.utils.makeVec2FromVec3OrVec2("t", {x=7, y=8})
            assert.equals(7, r.x)
            assert.equals(8, r.y)
        end)

        it("returns nil for nil input", function()
            assert.is_nil(ctld.utils.makeVec2FromVec3OrVec2("t", nil))
        end)

    end)

    -- ── rotateVec3 ───────────────────────────────────────────
    describe("rotateVec3", function()

        it("heading 0° is identity", function()
            local r = ctld.utils.rotateVec3({x=1, y=5, z=0}, 0)
            assert.is_true(approxEq(r.x, 1))
            assert.is_true(approxEq(r.z, 0))
            assert.equals(5, r.y)
        end)

        it("heading 90°: {x=1,z=0} → {x≈0,z≈-1}", function()
            local r = ctld.utils.rotateVec3({x=1, y=0, z=0}, 90)
            assert.is_true(approxEq(r.x,  0, 1e-5))
            assert.is_true(approxEq(r.z, -1, 1e-5))
        end)

        it("heading 90°: {x=0,z=1} → {x≈1,z≈0}", function()
            local r = ctld.utils.rotateVec3({x=0, y=0, z=1}, 90)
            assert.is_true(approxEq(r.x, 1, 1e-5))
            assert.is_true(approxEq(r.z, 0, 1e-5))
        end)

    end)

    -- ── polarToCartesian ─────────────────────────────────────
    describe("polarToCartesian", function()

        it("heading=0, angle=0: x=d*2, z=0", function()
            local r = ctld.utils.polarToCartesian(10, 0, 0)
            assert.is_true(approxEq(r.x, 20, 1e-5))
            assert.is_true(approxEq(r.z,  0, 1e-5))
        end)

        it("heading=90, angle=0: x≈0, z=d*2", function()
            local r = ctld.utils.polarToCartesian(10, 0, 90)
            assert.is_true(approxEq(r.x,  0, 1e-5))
            assert.is_true(approxEq(r.z, 20, 1e-5))
        end)

        it("distance=0 yields zero vector", function()
            local r = ctld.utils.polarToCartesian(0, 45, 45)
            assert.is_true(approxEq(r.x, 0))
            assert.is_true(approxEq(r.z, 0))
        end)

    end)

    -- ── deepCopy ─────────────────────────────────────────────
    describe("deepCopy", function()

        it("returns a distinct table", function()
            local orig = {a=1, b={c=2}}
            local copy = ctld.utils.deepCopy("t", orig)
            assert.not_equal(orig, copy)
            assert.equals(1, copy.a)
            assert.equals(2, copy.b.c)
        end)

        it("copies nested tables independently", function()
            local orig = {b={c=2}}
            local copy = ctld.utils.deepCopy("t", orig)
            assert.not_equal(orig.b, copy.b)
        end)

        it("mutation of original does not affect copy", function()
            local orig = {a=1}
            local copy = ctld.utils.deepCopy("t", orig)
            orig.a = 99
            assert.equals(1, copy.a)
        end)

        it("returns nil for nil input", function()
            assert.is_nil(ctld.utils.deepCopy("t", nil))
        end)

    end)

    -- ── isValueInIpairTable ───────────────────────────────────
    describe("isValueInIpairTable", function()

        it("returns true when value is present", function()
            assert.is_true(ctld.utils.isValueInIpairTable("t", {10,20,30}, 20))
        end)

        it("returns false when value is absent", function()
            assert.is_false(ctld.utils.isValueInIpairTable("t", {10,20,30}, 99))
        end)

        it("returns false for nil table", function()
            assert.is_false(ctld.utils.isValueInIpairTable("t", nil, 10))
        end)

    end)

    -- ── countTableEntries ─────────────────────────────────────
    describe("countTableEntries", function()

        it("counts string-key entries", function()
            assert.equals(3, ctld.utils.countTableEntries("t", {a=1,b=2,c=3}))
        end)

        it("counts ipairs entries", function()
            assert.equals(4, ctld.utils.countTableEntries("t", {1,2,3,4}))
        end)

        it("returns 0 for empty table", function()
            assert.equals(0, ctld.utils.countTableEntries("t", {}))
        end)

        it("returns 0 for non-table", function()
            assert.equals(0, ctld.utils.countTableEntries("t", "notatable"))
        end)

    end)

    -- ── getNextUniqId ─────────────────────────────────────────
    describe("getNextUniqId", function()

        it("returns a number", function()
            assert.equals("number", type(ctld.utils.getNextUniqId()))
        end)

        it("is strictly monotone increasing", function()
            local id1 = ctld.utils.getNextUniqId()
            local id2 = ctld.utils.getNextUniqId()
            local id3 = ctld.utils.getNextUniqId()
            assert.equals(id1 + 1, id2)
            assert.equals(id2 + 1, id3)
        end)

    end)

    -- ── zoneToVec3 ────────────────────────────────────────────
    describe("zoneToVec3", function()

        it("extracts point from {point={x,y,z}} zone", function()
            local r = ctld.utils.zoneToVec3("t", {point={x=100, y=50, z=200}})
            assert.is_not_nil(r)
            assert.equals(100, r.x)
            assert.equals(50,  r.y)
            assert.equals(200, r.z)
        end)

        it("handles {x,y,z} table zone directly", function()
            local r = ctld.utils.zoneToVec3("t", {x=10, y=20, z=30})
            assert.is_not_nil(r)
            assert.equals(10, r.x)
            assert.equals(30, r.z)
        end)

        it("returns nil for nil zone", function()
            assert.is_nil(ctld.utils.zoneToVec3("t", nil))
        end)

    end)

    -- ── getGroupId ───────────────────────────────────────────
    describe("getGroupId", function()

        it("returns -1 for nil unit", function()
            assert.equals(-1, ctld.utils.getGroupId(nil))
        end)

        it("returns -1 when unit:getGroup() returns nil", function()
            local unit = { getGroup = function() return nil end }
            assert.equals(-1, ctld.utils.getGroupId(unit))
        end)

        it("returns group id when unit and group are valid", function()
            local unit = { getGroup = function()
                return { getID = function() return 42 end }
            end }
            assert.equals(42, ctld.utils.getGroupId(unit))
        end)

    end)

    -- ── inAir ────────────────────────────────────────────────
    describe("inAir", function()

        it("returns false for nil unit", function()
            assert.is_false(ctld.utils.inAir(nil))
        end)

        it("returns false when unit has no inAir method", function()
            local unit = {}
            assert.is_false(ctld.utils.inAir(unit))
        end)

        it("returns false when unit:inAir() returns false", function()
            local unit = { inAir = function() return false end }
            assert.is_false(ctld.utils.inAir(unit))
        end)

    end)

end)
