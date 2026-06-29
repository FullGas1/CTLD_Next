---@diagnostic disable
-- tests/unit/config_spec.lua
-- busted specs for CTLDConfig: singleton, load idempotency, getSetting defaults, gs(), to_type(), parseYAML()
-- Reference: live_tests/unit/U-084 through U-089
-- ============================================================

describe("CTLDConfig", function()

    local cfg

    before_each(function()
        CTLDConfig._instance = nil
        ctld.yamlConfigDatas = nil
        cfg = CTLDConfig.get()
        cfg:load()
    end)

    -- ── Singleton ────────────────────────────────────────────
    describe("get()", function()

        it("returns a non-nil instance", function()
            assert.is_not_nil(cfg)
        end)

        it("returns the same reference on multiple calls", function()
            local b = CTLDConfig.get()
            assert.equals(cfg, b)
        end)

        it("instance has a settings table", function()
            assert.equals("table", type(cfg.settings))
        end)

        it("isLoaded is true after init", function()
            assert.is_true(cfg.isLoaded)
        end)

        it("mutation via one reference is visible through another", function()
            local b = CTLDConfig.get()
            local orig = cfg.settings["numberOfTroops"]
            cfg.settings["numberOfTroops"] = 999
            assert.equals(999, b.settings["numberOfTroops"])
            cfg.settings["numberOfTroops"] = orig  -- restore
        end)

    end)

    -- ── load() idempotency ────────────────────────────────────
    describe("load()", function()

        it("second call returns true", function()
            local ok, _ = cfg:load()
            assert.is_true(ok)
        end)

        it("second call returns 'already loaded' message", function()
            local _, msg = cfg:load()
            assert.equals("string", type(msg))
            assert.is_not_nil(msg:find("already"))
        end)

        it("second call does not reset settings to defaults", function()
            local orig = cfg.settings["numberOfTroops"]
            cfg.settings["numberOfTroops"] = 77
            cfg:load()
            assert.equals(77, cfg.settings["numberOfTroops"])
            cfg.settings["numberOfTroops"] = orig  -- restore
        end)

    end)

    -- ── getSetting() default values ───────────────────────────
    describe("getSetting() defaults", function()

        it("addPlayerAircraftByType defaults to true", function()
            assert.is_true(cfg:getSetting("addPlayerAircraftByType"))
        end)

        it("disableAllSmoke defaults to false", function()
            assert.is_false(cfg:getSetting("disableAllSmoke"))
        end)

        it("maximumDistanceLogistic defaults to 200", function()
            assert.equals(200, cfg:getSetting("maximumDistanceLogistic"))
        end)

        it("minimumHoverHeight defaults to 7.5", function()
            assert.equals(7.5, cfg:getSetting("minimumHoverHeight"))
        end)

        it("hoverTime defaults to 10", function()
            assert.equals(10, cfg:getSetting("hoverTime"))
        end)

        it("numberOfTroops defaults to 10", function()
            assert.equals(10, cfg:getSetting("numberOfTroops"))
        end)

        it("maxExtractDistance defaults to 125", function()
            assert.equals(125, cfg:getSetting("maxExtractDistance"))
        end)

        it("JTAC_maxDistance defaults to 10000", function()
            assert.equals(10000, cfg:getSetting("JTAC_maxDistance"))
        end)

    end)

    -- ── ctld.gs() shortcut ────────────────────────────────────
    describe("ctld.gs()", function()

        it("returns same value as getSetting for numberOfTroops", function()
            assert.equals(cfg:getSetting("numberOfTroops"), ctld.gs("numberOfTroops"))
        end)

        it("returns same value as getSetting for maximumDistanceLogistic", function()
            assert.equals(cfg:getSetting("maximumDistanceLogistic"), ctld.gs("maximumDistanceLogistic"))
        end)

        it("returns same value as getSetting for buildTimeFOB", function()
            assert.equals(cfg:getSetting("buildTimeFOB"), ctld.gs("buildTimeFOB"))
        end)

        it("returns nil for unknown key", function()
            assert.is_nil(ctld.gs("__nonexistent_key_xyz__"))
        end)

    end)

    -- ── CTLDConfig.to_type() ──────────────────────────────────
    describe("to_type()", function()

        it("converts 'true' string to boolean true", function()
            assert.is_true(CTLDConfig.to_type("true"))
        end)

        it("converts 'false' string to boolean false", function()
            assert.is_false(CTLDConfig.to_type("false"))
        end)

        it("converts integer string to number", function()
            assert.equals(42, CTLDConfig.to_type("42"))
        end)

        it("converts float string to number", function()
            assert.equals(3.14, CTLDConfig.to_type("3.14"))
        end)

        it("converts '0' to number 0", function()
            assert.equals(0, CTLDConfig.to_type("0"))
        end)

        it("strips single quotes from string", function()
            assert.equals("hello", CTLDConfig.to_type("'hello'"))
        end)

        it("strips double quotes from string", function()
            assert.equals("world", CTLDConfig.to_type('"world"'))
        end)

        it("preserves unquoted string as-is", function()
            assert.equals("beacon.ogg", CTLDConfig.to_type("beacon.ogg"))
        end)

    end)

    -- ── CTLDConfig.parseYAML() ────────────────────────────────
    describe("parseYAML()", function()

        it("parses a simple string value", function()
            local t = CTLDConfig.parseYAML("myKey: hello")
            assert.equals("hello", t["myKey"])
        end)

        it("coerces integer value to number", function()
            local t = CTLDConfig.parseYAML("count: 42")
            assert.equals(42, t["count"])
        end)

        it("coerces boolean value", function()
            local t = CTLDConfig.parseYAML("flag: true")
            assert.is_true(t["flag"])
        end)

        it("coerces float value", function()
            local t = CTLDConfig.parseYAML("ratio: 0.5")
            assert.equals(0.5, t["ratio"])
        end)

        it("preserves dotted key as-is", function()
            local t = CTLDConfig.parseYAML("ctld.numberOfTroops: 25")
            assert.equals(25, t["ctld.numberOfTroops"])
        end)

        it("parses multiple lines", function()
            local t = CTLDConfig.parseYAML("ctld.buildTimeFOB: 60\nctld.cratesRequiredForFOB: 5")
            assert.equals(60, t["ctld.buildTimeFOB"])
            assert.equals(5,  t["ctld.cratesRequiredForFOB"])
        end)

        it("returns an empty table for empty input", function()
            local t = CTLDConfig.parseYAML("")
            assert.equals("table", type(t))
        end)

    end)

end)
