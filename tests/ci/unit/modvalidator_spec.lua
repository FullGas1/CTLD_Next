---@diagnostic disable
-- tests/unit/modvalidator_spec.lua
-- busted specs for CTLDModValidator: singleton, cache API, cache-hit short-circuit
-- Reference: live_tests/unit/U-106, U-107, U-108
-- Note: actual DCS spawn probes (C1/C2 in each U-xx) require a live DCS environment
--       and are marked pending here. Cache-hit tests (C3/C4) run in busted.
-- ============================================================

-- Resolve repo root to dofile the validator (not loaded by default loader)
local _thisFile = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]unit[\\/]")
if not _thisFile then _thisFile = "" end  -- relative path: cwd is repo root

-- ─────────────────────────────────────────────────────────────
describe("CTLDModValidator", function()

    setup(function()
        dofile(_thisFile .. "src/core/CTLD_modValidator.lua")
    end)

    before_each(function()
        -- Reset singleton before each test for isolation
        CTLDModValidator._instance = nil
    end)

    -- ── singleton ─────────────────────────────────────────────
    describe("singleton", function()

        it("getInstance() returns non-nil", function()
            assert.is_not_nil(CTLDModValidator.getInstance())
        end)

        it("getInstance() is idempotent", function()
            local a = CTLDModValidator.getInstance()
            local b = CTLDModValidator.getInstance()
            assert.equals(a, b)
        end)

        it("_cache is initialised as an empty table", function()
            local mv = CTLDModValidator.getInstance()
            assert.equals("table", type(mv._cache))
            assert.equals(0, (function() local n=0; for _ in pairs(mv._cache) do n=n+1 end; return n end)())
        end)

        it("_probeIdx starts at 0", function()
            local mv = CTLDModValidator.getInstance()
            assert.equals(0, mv._probeIdx)
        end)

    end)

    -- ── public API ────────────────────────────────────────────
    describe("public API (isGroundInvalid / isStaticInvalid)", function()

        it("isGroundInvalid returns false for an unknown typename (not probed)", function()
            local mv = CTLDModValidator.getInstance()
            assert.is_false(mv:isGroundInvalid("SomeUnknownType_XYZ"))
        end)

        it("isStaticInvalid returns false for an unknown typename (not probed)", function()
            local mv = CTLDModValidator.getInstance()
            assert.is_false(mv:isStaticInvalid("SomeUnknownType_XYZ"))
        end)

        it("isGroundInvalid returns true when cache marks the type false", function()
            local mv = CTLDModValidator.getInstance()
            mv._cache["G:FakeType"] = false
            assert.is_true(mv:isGroundInvalid("FakeType"))
        end)

        it("isStaticInvalid returns true when cache marks the type false", function()
            local mv = CTLDModValidator.getInstance()
            mv._cache["S:FakeStatic"] = false
            assert.is_true(mv:isStaticInvalid("FakeStatic"))
        end)

    end)

    -- ── U-106 : _probeGround cache-hit ────────────────────────
    describe("U-106 — _probeGround cache-hit (C3/C4)", function()

        it("C3: pre-cached true → returns true, _probeIdx unchanged", function()
            local mv = CTLDModValidator.getInstance()
            mv._probePos = { x = 0, z = 0 }
            mv._cache["G:CachedValidType"] = true
            local snap = mv._probeIdx
            local result = mv:_probeGround("CachedValidType")
            assert.is_true(result)
            assert.equals(snap, mv._probeIdx)
        end)

        it("C4: pre-cached false → returns false, _probeIdx unchanged", function()
            local mv = CTLDModValidator.getInstance()
            mv._probePos = { x = 0, z = 0 }
            mv._cache["G:CachedInvalidType"] = false
            local snap = mv._probeIdx
            local result = mv:_probeGround("CachedInvalidType")
            assert.is_false(result)
            assert.equals(snap, mv._probeIdx)
        end)

        -- Live DCS required: C1 (valid GROUND spawn) and C2 (invalid GROUND spawn)
        it("C1: valid GROUND type probe via DCS coalition.addGroup — requires live DCS", function()
            pending("needs DCS: coalition.addGroup + unit:getTypeName()")
        end)

        it("C2: invalid GROUND type probe via DCS coalition.addGroup — requires live DCS", function()
            pending("needs DCS: coalition.addGroup + unit:getTypeName()")
        end)

    end)

    -- ── U-107 : _probeStatic cache-hit ────────────────────────
    describe("U-107 — _probeStatic cache-hit (C3/C4)", function()

        it("C3: pre-cached true → returns true, _probeIdx unchanged", function()
            local mv = CTLDModValidator.getInstance()
            mv._probePos = { x = 0, z = 0 }
            mv._cache["S:CachedValidStatic"] = true
            local snap = mv._probeIdx
            local result = mv:_probeStatic("CachedValidStatic", "Fortifications", {})
            assert.is_true(result)
            assert.equals(snap, mv._probeIdx)
        end)

        it("C4: pre-cached false → returns false, _probeIdx unchanged", function()
            local mv = CTLDModValidator.getInstance()
            mv._probePos = { x = 0, z = 0 }
            mv._cache["S:CachedInvalidStatic"] = false
            local snap = mv._probeIdx
            local result = mv:_probeStatic("CachedInvalidStatic", "Fortifications", {})
            assert.is_false(result)
            assert.equals(snap, mv._probeIdx)
        end)

        it("C1: valid STATIC type probe via DCS coalition.addStaticObject — requires live DCS", function()
            pending("needs DCS: coalition.addStaticObject return value")
        end)

        it("C2: invalid STATIC type probe via DCS coalition.addStaticObject — requires live DCS", function()
            pending("needs DCS: coalition.addStaticObject return value")
        end)

    end)

    -- ── U-108 : _probeHeliport cache-hit ─────────────────────
    describe("U-108 — _probeHeliport cache-hit (C3/C4)", function()

        it("C3: pre-cached true → returns true, _probeIdx unchanged", function()
            local mv = CTLDModValidator.getInstance()
            mv._probePos = { x = 0, z = 0 }
            mv._cache["S:CachedValidHeliport"] = true
            local snap = mv._probeIdx
            local result = mv:_probeHeliport("CachedValidHeliport", "Heliports", {})
            assert.is_true(result)
            assert.equals(snap, mv._probeIdx)
        end)

        it("C4: pre-cached false → returns false, _probeIdx unchanged", function()
            local mv = CTLDModValidator.getInstance()
            mv._probePos = { x = 0, z = 0 }
            mv._cache["S:CachedInvalidHeliport"] = false
            local snap = mv._probeIdx
            local result = mv:_probeHeliport("CachedInvalidHeliport", "Heliports", {})
            assert.is_false(result)
            assert.equals(snap, mv._probeIdx)
        end)

        it("C1: valid HELIPORT type probe via getDesc().life — requires live DCS", function()
            pending("needs DCS: StaticObject.getByName + getDesc().life > 0")
        end)

        it("C2: invalid HELIPORT type probe via getDesc().life — requires live DCS", function()
            pending("needs DCS: StaticObject.getByName + getDesc().life == 0")
        end)

    end)

end)
