---@diagnostic disable
-- tests/unit/core_spec.lua
-- busted specs for CTLDDCSEventBridge (singleton, register, route) and
-- CTLDPlayerTracker (getPlayerByUnit, isPlayerUnit, getUnitByPlayer, getAllPlayers)
-- Reference: live_tests/unit/U-005 through U-007
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDDCSEventBridge", function()
    -- U-005

    before_each(function()
        CTLDDCSEventBridge._instance = nil
    end)

    -- ── Singleton ────────────────────────────────────────────
    describe("singleton", function()

        it("getInstance() returns a non-nil instance", function()
            assert.is_not_nil(CTLDDCSEventBridge.getInstance())
        end)

        it("getInstance() is idempotent", function()
            local a = CTLDDCSEventBridge.getInstance()
            local b = CTLDDCSEventBridge.getInstance()
            assert.equals(a, b)
        end)

        it("_handlers is a table", function()
            assert.equals("table", type(CTLDDCSEventBridge.getInstance()._handlers))
        end)

    end)

    -- ── register ─────────────────────────────────────────────
    describe("register()", function()

        local bridge, fakeEventId

        before_each(function()
            bridge      = CTLDDCSEventBridge.getInstance()
            fakeEventId = 9999
        end)

        it("creates a handler list for the event id", function()
            local mgr = { onFake = function() end }
            bridge:register(mgr, fakeEventId, "onFake")
            assert.is_not_nil(bridge._handlers[fakeEventId])
        end)

        it("exactly 1 handler registered after one register()", function()
            local mgr = { onFake = function() end }
            bridge:register(mgr, fakeEventId, "onFake")
            assert.equals(1, #bridge._handlers[fakeEventId])
        end)

    end)

    -- ── onEvent routing ──────────────────────────────────────
    describe("onEvent()", function()

        local bridge, fakeEventId, received

        before_each(function()
            bridge      = CTLDDCSEventBridge.getInstance()
            fakeEventId = 9999
            received    = nil
            local mgr = {
                onFake = function(self, event) received = event end,
            }
            bridge:register(mgr, fakeEventId, "onFake")
        end)

        it("dispatches event to registered handler", function()
            bridge:onEvent({ id = fakeEventId })
            assert.is_not_nil(received)
        end)

        it("event.id is passed to handler", function()
            bridge:onEvent({ id = fakeEventId, initiator = nil })
            assert.equals(fakeEventId, received.id)
        end)

        it("unknown event id does not throw", function()
            assert.has_no_error(function()
                bridge:onEvent({ id = 88888 })
            end)
        end)

        it("crashing handler is isolated (no propagation)", function()
            local crashMgr = {
                onCrash = function(self, e) error("handler crash") end,
            }
            bridge:register(crashMgr, fakeEventId, "onCrash")
            assert.has_no_error(function()
                bridge:onEvent({ id = fakeEventId })
            end)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerTracker getPlayerByUnit / isPlayerUnit", function()
    -- U-006
    -- Uses lightweight instance (no init()) to avoid DCS-event side effects.

    local tracker

    before_each(function()
        tracker            = setmetatable({}, CTLDPlayerTracker)
        tracker._byUnit    = {}
        tracker._byPlayer  = {}
        -- Inject two players
        tracker._byUnit["unit_alpha"]    = "PlayerAlpha"
        tracker._byUnit["unit_bravo"]    = "PlayerBravo"
        tracker._byPlayer["PlayerAlpha"] = { unitName = "unit_alpha", coalition = 2 }
        tracker._byPlayer["PlayerBravo"] = { unitName = "unit_bravo", coalition = 1 }
    end)

    -- ── getPlayerByUnit ──────────────────────────────────────
    describe("getPlayerByUnit()", function()

        it("returns player name for known unit", function()
            assert.equals("PlayerAlpha", tracker:getPlayerByUnit("unit_alpha"))
        end)

        it("returns second player name for known unit", function()
            assert.equals("PlayerBravo", tracker:getPlayerByUnit("unit_bravo"))
        end)

        it("returns nil for unknown unit", function()
            assert.is_nil(tracker:getPlayerByUnit("unit_unknown"))
        end)

    end)

    -- ── isPlayerUnit ────────────────────────────────────────
    describe("isPlayerUnit()", function()

        it("returns true for registered unit", function()
            assert.is_true(tracker:isPlayerUnit("unit_alpha"))
        end)

        it("returns true for second registered unit", function()
            assert.is_true(tracker:isPlayerUnit("unit_bravo"))
        end)

        it("returns false for AI unit", function()
            assert.is_false(tracker:isPlayerUnit("unit_ai"))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerTracker getUnitByPlayer / getAllPlayers", function()
    -- U-007

    local tracker

    before_each(function()
        tracker            = setmetatable({}, CTLDPlayerTracker)
        tracker._byUnit    = {}
        tracker._byPlayer  = {}
        -- Inject three players
        tracker._byUnit["unit_charlie"]    = "PlayerCharlie"
        tracker._byUnit["unit_delta"]      = "PlayerDelta"
        tracker._byUnit["unit_echo"]       = "PlayerEcho"
        tracker._byPlayer["PlayerCharlie"] = { unitName = "unit_charlie", coalition = 2 }
        tracker._byPlayer["PlayerDelta"]   = { unitName = "unit_delta",   coalition = 2 }
        tracker._byPlayer["PlayerEcho"]    = { unitName = "unit_echo",    coalition = 1 }
    end)

    -- ── getUnitByPlayer ──────────────────────────────────────
    describe("getUnitByPlayer()", function()

        it("returns data for known player", function()
            assert.is_not_nil(tracker:getUnitByPlayer("PlayerCharlie"))
        end)

        it("unitName is correct", function()
            assert.equals("unit_charlie", tracker:getUnitByPlayer("PlayerCharlie").unitName)
        end)

        it("coalition BLUE == 2", function()
            assert.equals(2, tracker:getUnitByPlayer("PlayerCharlie").coalition)
        end)

        it("coalition RED == 1", function()
            assert.equals(1, tracker:getUnitByPlayer("PlayerEcho").coalition)
        end)

        it("returns nil for unknown player", function()
            assert.is_nil(tracker:getUnitByPlayer("PlayerUnknown"))
        end)

    end)

    -- ── getAllPlayers ────────────────────────────────────────
    describe("getAllPlayers()", function()

        it("returns 3 entries", function()
            assert.equals(3, #tracker:getAllPlayers())
        end)

        it("every entry has playerName", function()
            for _, e in ipairs(tracker:getAllPlayers()) do
                assert.is_not_nil(e.playerName)
            end
        end)

        it("every entry has unitName", function()
            for _, e in ipairs(tracker:getAllPlayers()) do
                assert.is_not_nil(e.unitName)
            end
        end)

        it("every entry has coalition", function()
            for _, e in ipairs(tracker:getAllPlayers()) do
                assert.is_not_nil(e.coalition)
            end
        end)

        it("empty tracker returns empty list", function()
            local empty       = setmetatable({}, CTLDPlayerTracker)
            empty._byUnit     = {}
            empty._byPlayer   = {}
            assert.equals(0, #empty:getAllPlayers())
        end)

    end)

end)
