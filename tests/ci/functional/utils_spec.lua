---@diagnostic disable
-- tests/functional/utils_spec.lua
-- busted specs for ctld.utils: getCentroid, calcDropPosition, getSpawnObjectPositions
-- Reference: live_tests/functional/F-078, F-079, F-080
-- ============================================================

describe("ctld.utils", function()

    -- ── F-078 : getCentroid ───────────────────────────────────────────
    describe("F-078 — getCentroid", function()

        local _origGetHeight

        before_each(function()
            _origGetHeight = land.getHeight
            land.getHeight = function(_) return 42 end
        end)

        after_each(function()
            land.getHeight = _origGetHeight
        end)

        it("4-point square → centroid x==5, z==5", function()
            local pts = { {x=0,z=0}, {x=10,z=0}, {x=10,z=10}, {x=0,z=10} }
            local c = ctld.utils.getCentroid("t", pts)
            assert.is_not_nil(c)
            assert.is_true(math.abs(c.x - 5) < 1e-6)
            assert.is_true(math.abs(c.z - 5) < 1e-6)
        end)

        it("y == land.getHeight() == 42", function()
            local pts = { {x=0,z=0}, {x=10,z=0}, {x=10,z=10}, {x=0,z=10} }
            local c = ctld.utils.getCentroid("t", pts)
            assert.equals(42, c.y)
        end)

        it("3 aligned points → centroid on line", function()
            local pts = { {x=0,z=0}, {x=6,z=0}, {x=3,z=9} }
            local c = ctld.utils.getCentroid("t", pts)
            assert.is_true(math.abs(c.x - 3) < 1e-6)
            assert.is_true(math.abs(c.z - 3) < 1e-6)
        end)

        it("empty table → nil", function()
            assert.is_nil(ctld.utils.getCentroid("t", {}))
        end)

        it("nil → nil", function()
            assert.is_nil(ctld.utils.getCentroid("t", nil))
        end)

    end)

    -- ── F-079 : calcDropPosition ──────────────────────────────────────
    describe("F-079 — calcDropPosition", function()

        local _origGetHeight

        before_each(function()
            _origGetHeight = land.getHeight
            land.getHeight = function(_) return 0 end
        end)

        after_each(function()
            land.getHeight = _origGetHeight
        end)

        local mockTransport = {
            getPoint    = function() return { x=0, y=1000, z=0 } end,
            getVelocity = function() return { x=100, y=0, z=0 } end,
        }

        it("descentTime == AGL/rate (1000m / 10m/s = 100s)", function()
            local _, dt = ctld.utils.calcDropPosition(mockTransport, 10)
            assert.equals(100, dt)
        end)

        it("landPos is non-nil", function()
            local pos = ctld.utils.calcDropPosition(mockTransport, 10)
            assert.is_not_nil(pos)
        end)

        it("landPos.y == 0 (flat terrain mock)", function()
            local pos = ctld.utils.calcDropPosition(mockTransport, 10)
            assert.equals(0, pos.y)
        end)

        it("inertia dominates: x > 2900 with vx=100 m/s, t=100s", function()
            local pos = ctld.utils.calcDropPosition(mockTransport, 10)
            assert.is_true(pos.x > 2900)
        end)

        it("lateral drift ≤ 80m when z-velocity is 0", function()
            local pos = ctld.utils.calcDropPosition(mockTransport, 10)
            assert.is_true(math.abs(pos.z) <= 81)
        end)

    end)

    -- ── F-080 : getSpawnObjectPositions ───────────────────────────────
    describe("F-080 — getSpawnObjectPositions", function()

        local mockUnit = {
            getPoint    = function() return { x=0, y=100, z=0 } end,
            getPosition = function()
                return {
                    p = { x=0, y=100, z=0 },
                    x = { x=1, y=0, z=0 },
                    y = { x=0, y=1, z=0 },
                    z = { x=0, y=0, z=1 },
                }
            end,
        }

        local result

        before_each(function()
            result = ctld.utils.getSpawnObjectPositions(mockUnit, 3, 10, 5)
        end)

        it("result is non-nil", function()
            assert.is_not_nil(result)
        end)

        it("result.positions has 3 entries", function()
            assert.is_not_nil(result.positions)
            assert.equals(3, #result.positions)
        end)

        it("result.distance == safeDistance == 10", function()
            assert.equals(10, result.distance)
        end)

        it("result.clock is a string between '1' and '12'", function()
            assert.equals("string", type(result.clock))
            local n = tonumber(result.clock)
            assert.is_not_nil(n)
            assert.is_true(n >= 1 and n <= 12)
        end)

        it("each position has x and z fields", function()
            for _, pos in ipairs(result.positions) do
                assert.is_not_nil(pos.x)
                assert.is_not_nil(pos.z)
            end
        end)

        it("consecutive positions are ~spacing apart (5m)", function()
            local function dist2D(a, b)
                return math.sqrt((a.x-b.x)^2 + (a.z-b.z)^2)
            end
            local d12 = dist2D(result.positions[1], result.positions[2])
            local d23 = dist2D(result.positions[2], result.positions[3])
            assert.is_true(math.abs(d12 - 5) < 0.01)
            assert.is_true(math.abs(d23 - 5) < 0.01)
        end)

    end)

end)
