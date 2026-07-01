---@diagnostic disable
-- tests/unit/event_dispatcher_spec.lua
-- busted specs for EventDispatcher: singleton, subscribe/publish, unsubscribe, error isolation
-- Reference: live_tests/unit/U-001 through U-004
-- ============================================================

describe("EventDispatcher", function()

    local ed

    before_each(function()
        EventDispatcher._instance = nil
        ed = EventDispatcher.getInstance()
    end)

    -- ── Singleton ────────────────────────────────────────────
    describe("singleton", function()

        it("getInstance returns a non-nil instance", function()
            assert.is_not_nil(ed)
        end)

        it("two calls to getInstance return the same reference", function()
            local inst2 = EventDispatcher.getInstance()
            assert.equals(ed, inst2)
        end)

        it("instance has a _listeners table", function()
            assert.equals("table", type(ed._listeners))
        end)

    end)

    -- ── subscribe + publish ───────────────────────────────────
    describe("subscribe / publish", function()

        it("subscribed callback is called with the correct payload", function()
            local received = nil
            ed:subscribe("TestEvent", function(p) received = p end)
            ed:publish("TestEvent", {value = 42})
            assert.is_not_nil(received)
            assert.equals(42, received.value)
        end)

        it("callback is not triggered for a different event", function()
            local received = nil
            ed:subscribe("OtherEvent", function(p) received = p end)
            ed:publish("TestEvent", {value = 99})
            assert.is_nil(received)
        end)

        it("multiple callbacks on the same event are all called once", function()
            local countA, countB = 0, 0
            ed:subscribe("MultiEvent", function() countA = countA + 1 end)
            ed:subscribe("MultiEvent", function() countB = countB + 1 end)
            ed:publish("MultiEvent", {})
            assert.equals(1, countA)
            assert.equals(1, countB)
        end)

        it("publish with no subscriber does not raise an error", function()
            assert.has_no_error(function()
                ed:publish("NoSubscriber", {x = 1})
            end)
        end)

    end)

    -- ── unsubscribe ───────────────────────────────────────────
    describe("unsubscribe", function()

        it("unsubscribed callback is no longer called", function()
            local count = 0
            local cb = function() count = count + 1 end
            ed:subscribe("EvA", cb)
            ed:publish("EvA", {})
            assert.equals(1, count)

            ed:unsubscribe("EvA", cb)
            ed:publish("EvA", {})
            assert.equals(1, count)
        end)

        it("unsubscribing one callback does not affect other callbacks on same event", function()
            local countB, countC = 0, 0
            local cbB = function() countB = countB + 1 end
            local cbC = function() countC = countC + 1 end
            ed:subscribe("EvB", cbB)
            ed:subscribe("EvB", cbC)
            ed:unsubscribe("EvB", cbB)
            ed:publish("EvB", {})
            assert.equals(0, countB)
            assert.equals(1, countC)
        end)

        it("unsubscribing a non-existent event does not raise an error", function()
            local cb = function() end
            assert.has_no_error(function()
                ed:unsubscribe("NonExistentEvent", cb)
            end)
        end)

        it("unsubscribing an unregistered callback does not raise an error", function()
            local cbA = function() end
            local cbD = function() end
            ed:subscribe("EvD", cbA)
            assert.has_no_error(function()
                ed:unsubscribe("EvD", cbD)
            end)
        end)

    end)

    -- ── error isolation ───────────────────────────────────────
    describe("error isolation", function()

        it("a throwing callback does not prevent subsequent callbacks from running", function()
            local good1, good2 = false, false
            ed:subscribe("IsoEvent", function() good1 = true end)
            ed:subscribe("IsoEvent", function() error("intentional error") end)
            ed:subscribe("IsoEvent", function() good2 = true end)

            assert.has_no_error(function() ed:publish("IsoEvent", {}) end)
            assert.is_true(good1)
            assert.is_true(good2)
        end)

        it("multiple throwing callbacks do not prevent the final callback", function()
            local final = false
            ed:subscribe("IsoEvent2", function() error("err1") end)
            ed:subscribe("IsoEvent2", function() error("err2") end)
            ed:subscribe("IsoEvent2", function() final = true end)

            assert.has_no_error(function() ed:publish("IsoEvent2", {}) end)
            assert.is_true(final)
        end)

    end)

end)
