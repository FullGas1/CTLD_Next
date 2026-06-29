---@diagnostic disable
-- tests/unit/recon_spec.lua
-- busted specs for CTLDReconRenderer.createIcon and CTLDReconManager._matchLayer
-- Reference: live_tests/unit/U-016 through U-017
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDReconRenderer createIcon routing", function()
    -- U-016

    local drawLog
    local origCircle, origLine, origRect

    local function resetLog() drawLog = {} end

    local function makeTarget(renderer)
        return {
            position  = { x = 0, y = 0, z = 0 },
            coalition = 1,   -- sets color via COALITION_COLORS[1] (RED)
            layer     = { iconRenderer = renderer, color = { 1, 0, 0, 1 } },
        }
    end

    before_each(function()
        drawLog    = {}
        origCircle = trigger.action.circleToAll
        origLine   = trigger.action.lineToAll
        origRect   = trigger.action.rectToAll
        trigger.action.circleToAll = function() table.insert(drawLog, "circle") end
        trigger.action.lineToAll   = function() table.insert(drawLog, "line")   end
        trigger.action.rectToAll   = function() table.insert(drawLog, "rect")   end
    end)

    after_each(function()
        trigger.action.circleToAll = origCircle
        trigger.action.lineToAll   = origLine
        trigger.action.rectToAll   = origRect
    end)

    it("infantry → 3 primitives, first = circle", function()
        CTLDReconRenderer.createIcon(makeTarget("infantry"), 1)
        assert.equals(3, #drawLog)
        assert.equals("circle", drawLog[1])
    end)

    it("vehicle → 2 primitives, first = rect", function()
        CTLDReconRenderer.createIcon(makeTarget("vehicle"), 2)
        assert.equals(2, #drawLog)
        assert.equals("rect", drawLog[1])
    end)

    it("aa → 3 primitives, first = circle (background)", function()
        -- drawAAIcon: circle background + 2 lines
        CTLDReconRenderer.createIcon(makeTarget("aa"), 3)
        assert.equals(3, #drawLog)
        assert.equals("circle", drawLog[1])
    end)

    it("aircraft → 3 primitives, last = circle", function()
        -- drawAircraftIcon: line + line + circle
        CTLDReconRenderer.createIcon(makeTarget("aircraft"), 4)
        assert.equals(3, #drawLog)
        assert.equals("circle", drawLog[3])
    end)

    it("helicopter → 3 primitives, first = circle", function()
        CTLDReconRenderer.createIcon(makeTarget("helicopter"), 5)
        assert.equals(3, #drawLog)
        assert.equals("circle", drawLog[1])
    end)

    it("ship → 3 primitives, first = rect", function()
        -- drawShipIcon: rect + line + line
        CTLDReconRenderer.createIcon(makeTarget("ship"), 6)
        assert.equals(3, #drawLog)
        assert.equals("rect", drawLog[1])
    end)

    it("unknown renderer → fallback circle (1 primitive)", function()
        CTLDReconRenderer.createIcon(makeTarget("unknown_xyz"), 7)
        assert.equals(1, #drawLog)
        assert.equals("circle", drawLog[1])
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDReconManager _matchLayer", function()
    -- U-017
    -- Uses a lightweight instance (setmetatable) to avoid init() side effects.
    -- IMPORTANT: test layers must include enabled=true; _matchLayer returns
    -- `layer.enabled and layer or nil`, so nil/false → nil even if attribute matches.

    local rm

    local testLayers = {
        { layerId = "infantry",       filterAttrib = "Infantry",    iconRenderer = "infantry", enabled = true },
        { layerId = "ground_vehicles", filterAttrib = "Vehicles",   iconRenderer = "vehicle",  enabled = true },
        { layerId = "air_defense",    filterAttrib = "Air Defence", iconRenderer = "aa",       enabled = true },
    }

    local function makeUnit(attribute)
        return {
            hasAttribute = function(self, attr) return attr == attribute end,
        }
    end

    before_each(function()
        rm = setmetatable({}, CTLDReconManager)
    end)

    it("Infantry unit → layer 'infantry'", function()
        local layer = rm:_matchLayer(makeUnit("Infantry"), testLayers)
        assert.is_not_nil(layer)
        assert.equals("infantry", layer.layerId)
    end)

    it("Vehicles unit → layer 'ground_vehicles'", function()
        local layer = rm:_matchLayer(makeUnit("Vehicles"), testLayers)
        assert.is_not_nil(layer)
        assert.equals("ground_vehicles", layer.layerId)
    end)

    it("Air Defence unit → layer 'air_defense'", function()
        local layer = rm:_matchLayer(makeUnit("Air Defence"), testLayers)
        assert.is_not_nil(layer)
        assert.equals("air_defense", layer.layerId)
    end)

    it("unit with unknown attribute → nil", function()
        assert.is_nil(rm:_matchLayer(makeUnit("Ships"), testLayers))
    end)

    it("empty layer list → nil", function()
        assert.is_nil(rm:_matchLayer(makeUnit("Infantry"), {}))
    end)

    it("layer.enabled=false → nil even if attribute matches", function()
        local disabledLayers = {
            { layerId = "inf", filterAttrib = "Infantry", enabled = false },
        }
        assert.is_nil(rm:_matchLayer(makeUnit("Infantry"), disabledLayers))
    end)

    it("hasAttribute() throws → pcall protects → nil", function()
        local crashUnit = {
            hasAttribute = function() error("simulated DCS API error") end,
        }
        assert.is_nil(rm:_matchLayer(crashUnit, testLayers))
    end)

end)
