---@diagnostic disable
-- tests/unit/vehicle_bbox_spec.lua
-- busted specs for CTLDVehicleSpawner bbox helpers (_worldToLocal, _isInBbox)
-- Reference: live_tests/unit/U-021
-- U-022 (getDesc().box on a live DCS unit) is DCS-dependent and cannot run in busted.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDVehicleSpawner _worldToLocal + _isInBbox", function()
    -- U-021

    -- Approx C-130J-30 cargo bay bbox: forward x, lateral z, vertical y
    local box = { min = { x = -15, y = -2, z = -3 }, max = { x = 15, y = 2, z = 3 } }

    -- Lightweight instance: these are pure-math methods, no DCS state needed.
    local vs

    before_each(function()
        vs = setmetatable({}, CTLDVehicleSpawner)
    end)

    -- ── _worldToLocal — identity transform ────────────────────
    describe("_worldToLocal identity transform", function()

        local tfId = {
            p = { x = 0, y = 0, z = 0 },
            x = { x = 1, y = 0, z = 0 },
            y = { x = 0, y = 1, z = 0 },
            z = { x = 0, y = 0, z = 1 },
        }

        it("identity: (5,0,0) → local.x ≈ 5", function()
            local lp = vs:_worldToLocal({ x = 5, y = 0, z = 0 }, tfId)
            assert.is_true(math.abs(lp.x - 5) < 0.001)
        end)

        it("identity: (5,0,0) → local.z ≈ 0", function()
            local lp = vs:_worldToLocal({ x = 5, y = 0, z = 0 }, tfId)
            assert.is_true(math.abs(lp.z) < 0.001)
        end)

        it("identity: origin stays at origin", function()
            local lp = vs:_worldToLocal({ x = 0, y = 0, z = 0 }, tfId)
            assert.is_true(math.abs(lp.x) < 0.001 and math.abs(lp.z) < 0.001)
        end)

    end)

    -- ── _worldToLocal — translation ───────────────────────────
    describe("_worldToLocal with translation", function()

        local tfT = {
            p = { x = 1000, y = 0, z = 2000 },
            x = { x = 1, y = 0, z = 0 },
            y = { x = 0, y = 1, z = 0 },
            z = { x = 0, y = 0, z = 1 },
        }

        it("(1005,0,2000) → local.x ≈ 5", function()
            local lp = vs:_worldToLocal({ x = 1005, y = 0, z = 2000 }, tfT)
            assert.is_true(math.abs(lp.x - 5) < 0.001)
        end)

        it("(1000,0,2003) → local.z ≈ 3", function()
            local lp = vs:_worldToLocal({ x = 1000, y = 0, z = 2003 }, tfT)
            assert.is_true(math.abs(lp.z - 3) < 0.001)
        end)

    end)

    -- ── _worldToLocal — 90° rotation CW around Y ─────────────
    describe("_worldToLocal with 90° rotation (forward = world +Z)", function()

        -- forward = world +Z, up = world +Y, right = world -X
        local tfR90 = {
            p = { x = 0, y = 0, z = 0 },
            x = { x = 0, y = 0, z = 1 },
            y = { x = 0, y = 1, z = 0 },
            z = { x = -1, y = 0, z = 0 },
        }

        it("world +Z 5m → local.x ≈ 5", function()
            local lp = vs:_worldToLocal({ x = 0, y = 0, z = 5 }, tfR90)
            assert.is_true(math.abs(lp.x - 5) < 0.001)
        end)

        it("world +X 5m → local.z ≈ -5 (right axis reversed)", function()
            local lp = vs:_worldToLocal({ x = 5, y = 0, z = 0 }, tfR90)
            assert.is_true(math.abs(lp.z + 5) < 0.001)
        end)

    end)

    -- ── _isInBbox — inside ────────────────────────────────────
    describe("_isInBbox inside", function()

        it("(5,0,0) is inside box", function()
            assert.is_true(vs:_isInBbox({ x = 5, y = 0, z = 0 }, box))
        end)

        it("(0,0,0) is inside box", function()
            assert.is_true(vs:_isInBbox({ x = 0, y = 0, z = 0 }, box))
        end)

        it("(14.9,1.9,2.9) is inside box (near max)", function()
            assert.is_true(vs:_isInBbox({ x = 14.9, y = 1.9, z = 2.9 }, box))
        end)

        it("point at exact max is inside box (inclusive)", function()
            assert.is_true(vs:_isInBbox({ x = 15, y = 2, z = 3 }, box))
        end)

    end)

    -- ── _isInBbox — outside ───────────────────────────────────
    describe("_isInBbox outside", function()

        it("(20,0,0) is outside box (x > max.x)", function()
            assert.is_false(vs:_isInBbox({ x = 20, y = 0, z = 0 }, box))
        end)

        it("(-20,0,0) is outside box (x < min.x)", function()
            assert.is_false(vs:_isInBbox({ x = -20, y = 0, z = 0 }, box))
        end)

        it("(0,0,5) is outside box (z > max.z)", function()
            assert.is_false(vs:_isInBbox({ x = 0, y = 0, z = 5 }, box))
        end)

        it("(0,3,0) is outside box (y > max.y)", function()
            assert.is_false(vs:_isInBbox({ x = 0, y = 3, z = 0 }, box))
        end)

    end)

    -- ── combined round-trip ───────────────────────────────────
    describe("_worldToLocal + _isInBbox combined", function()

        local tfId = {
            p = { x = 0, y = 0, z = 0 },
            x = { x = 1, y = 0, z = 0 },
            y = { x = 0, y = 1, z = 0 },
            z = { x = 0, y = 0, z = 1 },
        }

        it("world (5,0,0) identity → inside box", function()
            local lp = vs:_worldToLocal({ x = 5, y = 0, z = 0 }, tfId)
            assert.is_true(vs:_isInBbox(lp, box))
        end)

        it("world (20,0,0) identity → outside box", function()
            local lp = vs:_worldToLocal({ x = 20, y = 0, z = 0 }, tfId)
            assert.is_false(vs:_isInBbox(lp, box))
        end)

        it("world +Z 5m with rotation → inside box", function()
            local tfR90 = {
                p = { x = 0, y = 0, z = 0 },
                x = { x = 0, y = 0, z = 1 },
                y = { x = 0, y = 1, z = 0 },
                z = { x = -1, y = 0, z = 0 },
            }
            local lp = vs:_worldToLocal({ x = 0, y = 0, z = 5 }, tfR90)
            assert.is_true(vs:_isInBbox(lp, box))
        end)

        it("translated (1005,0,2000) with translation tf → inside box", function()
            local tfT = {
                p = { x = 1000, y = 0, z = 2000 },
                x = { x = 1, y = 0, z = 0 },
                y = { x = 0, y = 1, z = 0 },
                z = { x = 0, y = 0, z = 1 },
            }
            local lp = vs:_worldToLocal({ x = 1005, y = 0, z = 2000 }, tfT)
            assert.is_true(vs:_isInBbox(lp, box))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDVehicleSpawner getDesc().box", function()
    -- U-022 — DCS live unit required (C-130J-30 with :getDesc()/:getTransformation())
    -- Cannot be tested in busted without a real DCS environment.
    -- Covered by live_tests/unit/U-022.

    pending("requires a live DCS unit (C-130J-30 in mission) — run via Witchcraft")

end)
