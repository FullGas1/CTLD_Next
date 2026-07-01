---@diagnostic disable
-- tests/functional/config_spec.lua
-- busted specs for CTLDConfig and CTLDi18n
-- Reference: live_tests/functional/F-101, F-102, F-103, F-104, F-105
-- ============================================================

-- Resolve repo root to dofile i18n language files
local _thisFile = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]functional[\\/]")
if not _thisFile then _thisFile = "" end  -- relative path: cwd is repo root

-- Load extra language dictionaries (not in default loader)
dofile(_thisFile .. "src/CTLD_i18n_fr.lua")
dofile(_thisFile .. "src/CTLD_i18n_es.lua")

-- ── F-101 / F-102 : CTLDConfig ────────────────────────────────────────────────
describe("CTLDConfig", function()

    local _origInstance
    local _origYaml

    before_each(function()
        _origInstance = CTLDConfig._instance
        _origYaml     = ctld.yamlConfigDatas
    end)

    after_each(function()
        CTLDConfig._instance  = _origInstance
        ctld.yamlConfigDatas  = _origYaml
    end)

    -- ── F-101 : yaml override ─────────────────────────────────────────
    describe("F-101 — yamlConfigDatas override", function()

        it("load() returns true", function()
            CTLDConfig._instance = nil
            ctld.yamlConfigDatas = "ctld.numberOfTroops: 25\n"
            local cfg = CTLDConfig.get()
            local ok = cfg:load()
            assert.equals(true, ok)
        end)

        it("overridden setting reflected", function()
            CTLDConfig._instance = nil
            ctld.yamlConfigDatas = "ctld.numberOfTroops: 25\n"
            local cfg = CTLDConfig.get()
            cfg:load()
            assert.equals(25, cfg:getSetting("numberOfTroops"))
        end)

        it("second overridden setting reflected", function()
            CTLDConfig._instance = nil
            ctld.yamlConfigDatas = "ctld.numberOfTroops: 25\nctld.maximumDistanceLogistic: 350\n"
            local cfg = CTLDConfig.get()
            cfg:load()
            assert.equals(350, cfg:getSetting("maximumDistanceLogistic"))
        end)

        it("non-overridden setting keeps default (hoverTime=10)", function()
            CTLDConfig._instance = nil
            ctld.yamlConfigDatas = "ctld.numberOfTroops: 25\n"
            local cfg = CTLDConfig.get()
            cfg:load()
            assert.equals(10, cfg:getSetting("hoverTime"))
        end)

    end)

    -- ── F-102 : singleton reset ───────────────────────────────────────
    describe("F-102 — singleton reset + fresh defaults", function()

        it("mutation is visible before reset", function()
            CTLDConfig.get().settings["numberOfTroops"] = 99
            assert.equals(99, ctld.gs("numberOfTroops"))
        end)

        it("fresh instance restores default numberOfTroops=10", function()
            CTLDConfig._instance = nil
            ctld.yamlConfigDatas = nil
            local fresh = CTLDConfig.get()
            fresh:load()
            assert.equals(10, fresh:getSetting("numberOfTroops"))
        end)

        it("fresh instance restores maximumDistanceLogistic=200", function()
            CTLDConfig._instance = nil
            ctld.yamlConfigDatas = nil
            local fresh = CTLDConfig.get()
            fresh:load()
            assert.equals(200, fresh:getSetting("maximumDistanceLogistic"))
        end)

        it("isLoaded == true after load()", function()
            CTLDConfig._instance = nil
            ctld.yamlConfigDatas = nil
            local fresh = CTLDConfig.get()
            fresh:load()
            assert.equals(true, fresh.isLoaded)
        end)

    end)

end)

-- ── F-103 : ctld.tr() fallback chain ──────────────────────────────────────────
describe("CTLDi18n ctld.tr()", function()

    local _origLang

    before_each(function()
        _origLang = ctld.i18n_lang
    end)

    after_each(function()
        ctld.i18n_lang = _origLang
    end)

    it("F-103a: fr lang returns FR translation (for a key with FR≠EN)", function()
        -- Find a key that has a proper FR translation
        local testKey, frValue
        for k, enVal in pairs(ctld.i18n["en"]) do
            if k ~= "translation_version" then
                local frVal = ctld.i18n["fr"] and ctld.i18n["fr"][k]
                if frVal ~= nil and frVal ~= enVal and type(frVal) == "string" then
                    testKey  = k
                    frValue  = frVal
                    break
                end
            end
        end
        assert.is_not_nil(testKey, "found a properly-translated FR key")
        ctld.i18n_lang = "fr"
        assert.equals(frValue, ctld.tr(testKey))
    end)

    it("F-103b: en lang returns EN value", function()
        local testKey
        for k, _ in pairs(ctld.i18n["en"]) do
            if k ~= "translation_version" then testKey = k break end
        end
        ctld.i18n_lang = "en"
        assert.equals(ctld.i18n["en"][testKey], ctld.tr(testKey))
    end)

    it("F-103c: unknown lang falls back to EN value", function()
        local testKey
        for k, _ in pairs(ctld.i18n["en"]) do
            if k ~= "translation_version" then testKey = k break end
        end
        ctld.i18n_lang = "xx"
        assert.equals(ctld.i18n["en"][testKey], ctld.tr(testKey))
    end)

    it("F-103d: completely unknown key returns the key itself", function()
        ctld.i18n_lang = "fr"
        local unknownKey = "__CTLD_TEST_NO_SUCH_KEY__"
        assert.equals(unknownKey, ctld.tr(unknownKey))
    end)

    it("F-103e: parameter substitution works", function()
        ctld.i18n["en"]["__TEST_PARAM__"] = "Hello %1, you have %2 items"
        ctld.i18n["fr"]["__TEST_PARAM__"] = "Bonjour %1, tu as %2 éléments"
        ctld.i18n_lang = "fr"
        local result = ctld.tr("__TEST_PARAM__", "Alice", 3)
        assert.equals("Bonjour Alice, tu as 3 éléments", result)
        ctld.i18n["en"]["__TEST_PARAM__"] = nil
        ctld.i18n["fr"]["__TEST_PARAM__"] = nil
    end)

end)

-- ── F-104 : FR completeness audit ─────────────────────────────────────────────
describe("CTLDi18n F-104 — FR completeness audit", function()

    it("ctld.i18n_audit function exists", function()
        assert.equals("function", type(ctld.i18n_audit))
    end)

    it("audit('fr') returns no error", function()
        local _, err = ctld.i18n_audit("fr")
        assert.is_nil(err)
    end)

    it("audit('fr') result is a table", function()
        local result = ctld.i18n_audit("fr")
        assert.equals("table", type(result))
    end)

    it("FR version matches EN version", function()
        local result = ctld.i18n_audit("fr")
        assert.equals(true, result.version_match,
            string.format("FR version=%s EN version=%s", tostring(result.lang_version), tostring(result.en_version)))
    end)

    it("FR has no missing keys", function()
        local result = ctld.i18n_audit("fr")
        assert.equals(0, #result.missing,
            string.format("FR missing %d keys", #result.missing))
    end)

end)

-- ── F-105 : ES+KO completeness audit ──────────────────────────────────────────
describe("CTLDi18n F-105 — ES and KO completeness audit", function()

    -- Load KO dict if not already loaded
    setup(function()
        if not (ctld.i18n and ctld.i18n["ko"]) then
            dofile(_thisFile .. "src/CTLD_i18n_ko.lua")
        end
    end)

    for _, lang in ipairs({"es", "ko"}) do
        local _lang = lang  -- capture for closure

        describe(_lang .. " dictionary", function()

            it("audit returns no error", function()
                local _, err = ctld.i18n_audit(_lang)
                assert.is_nil(err)
            end)

            it("audit returns a table", function()
                local result = ctld.i18n_audit(_lang)
                assert.equals("table", type(result))
            end)

            it("version matches EN", function()
                local result = ctld.i18n_audit(_lang)
                assert.equals(true, result.version_match,
                    string.format("%s version=%s EN=%s", _lang,
                        tostring(result.lang_version), tostring(result.en_version)))
            end)

            it("no missing keys", function()
                local result = ctld.i18n_audit(_lang)
                assert.equals(0, #result.missing,
                    string.format("%s missing %d keys", _lang, #result.missing))
            end)

        end)
    end

end)
