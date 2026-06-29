---@diagnostic disable
-- tests/unit/i18n_spec.lua
-- busted specs for CTLDi18n: audit function, return structure, mock detection, auditAll
-- Reference: live_tests/unit/U-090 through U-096
-- Note: loader.lua only loads CTLD_i18n_en.lua. FR/ES/KO loaded once below.
-- ============================================================

-- Resolve repo root from this file's path
local _root = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]unit[\\/]")
if not _root then _root = "" end  -- relative path: cwd is repo root
local SRC = _root .. "src/"

-- Load non-EN dictionaries once (idempotent: ctld.i18n["fr"] will already exist if reloaded)
dofile(SRC .. "CTLD_i18n_fr.lua")
dofile(SRC .. "CTLD_i18n_es.lua")
dofile(SRC .. "CTLD_i18n_ko.lua")

-- ─────────────────────────────────────────────────────────────
describe("CTLDi18n", function()

    -- ── Existence and callability ─────────────────────────────
    describe("ctld.i18n_audit() existence", function()

        it("ctld.i18n_audit is a function", function()
            assert.equals("function", type(ctld.i18n_audit))
        end)

        it("ctld.i18n_auditAll is a function", function()
            assert.equals("function", type(ctld.i18n_auditAll))
        end)

        it("calling with 'en' does not throw", function()
            assert.has_no_error(function() ctld.i18n_audit("en") end)
        end)

        it("calling with 'en' returns a table", function()
            local result = ctld.i18n_audit("en")
            assert.equals("table", type(result))
        end)

    end)

    -- ── Return structure (FR) ─────────────────────────────────
    describe("ctld.i18n_audit() return structure", function()

        local result

        before_each(function()
            result = ctld.i18n_audit("fr")
        end)

        it("returns no error for known language 'fr'", function()
            local _, err = ctld.i18n_audit("fr")
            assert.is_nil(err)
        end)

        it("result is a table", function()
            assert.equals("table", type(result))
        end)

        it("result.version_match field is present", function()
            assert.is_not_nil(result.version_match)
        end)

        it("result.en_version is a string", function()
            assert.equals("string", type(result.en_version))
        end)

        it("result.lang_version is a string", function()
            assert.equals("string", type(result.lang_version))
        end)

        it("result.missing is a table", function()
            assert.equals("table", type(result.missing))
        end)

        it("result.untranslated is a table", function()
            assert.equals("table", type(result.untranslated))
        end)

        it("en_version is '1.8'", function()
            assert.equals("1.8", result.en_version)
        end)

    end)

    -- ── Unknown language ─────────────────────────────────────
    describe("ctld.i18n_audit() unknown language", function()

        it("returns nil result for unknown language", function()
            local result, _ = ctld.i18n_audit("zz")
            assert.is_nil(result)
        end)

        it("returns a non-empty error string", function()
            local _, err = ctld.i18n_audit("zz")
            assert.equals("string", type(err))
            assert.is_true(#err > 0)
        end)

        it("error string mentions the unknown language code", function()
            local _, err = ctld.i18n_audit("zz")
            assert.is_not_nil(err:find("zz"))
        end)

    end)

    -- ── Detects missing key (mock) ────────────────────────────
    describe("ctld.i18n_audit() detects missing key", function()

        local testKey, origFR

        before_each(function()
            -- Pick any non-version key from EN
            for k in pairs(ctld.i18n["en"]) do
                if k ~= "translation_version" then testKey = k; break end
            end
            origFR = ctld.i18n["fr"][testKey]
            ctld.i18n["fr"][testKey] = nil
        end)

        after_each(function()
            ctld.i18n["fr"][testKey] = origFR
        end)

        it("testKey is found in EN", function()
            assert.is_not_nil(testKey)
        end)

        it("removed key appears in result.missing", function()
            local result = ctld.i18n_audit("fr")
            local found = false
            for _, k in ipairs(result.missing) do
                if k == testKey then found = true; break end
            end
            assert.is_true(found)
        end)

        it("removed key does not appear in result.untranslated", function()
            local result = ctld.i18n_audit("fr")
            local found = false
            for _, k in ipairs(result.untranslated) do
                if k == testKey then found = true; break end
            end
            assert.is_false(found)
        end)

    end)

    -- ── Detects untranslated key (mock) ───────────────────────
    describe("ctld.i18n_audit() detects untranslated key", function()

        local testKey, origFR

        before_each(function()
            -- Find a key that has a real FR translation (differs from EN)
            for k, enVal in pairs(ctld.i18n["en"]) do
                if k ~= "translation_version" then
                    local frVal = ctld.i18n["fr"][k]
                    if frVal ~= nil and frVal ~= enVal then
                        testKey = k; origFR = frVal; break
                    end
                end
            end
            if testKey then
                ctld.i18n["fr"][testKey] = ctld.i18n["en"][testKey]
            end
        end)

        after_each(function()
            if testKey then ctld.i18n["fr"][testKey] = origFR end
        end)

        it("mocked key appears in result.untranslated", function()
            assert.is_not_nil(testKey)
            local result = ctld.i18n_audit("fr")
            local found = false
            for _, k in ipairs(result.untranslated) do
                if k == testKey then found = true; break end
            end
            assert.is_true(found)
        end)

        it("mocked key does not appear in result.missing", function()
            assert.is_not_nil(testKey)
            local result = ctld.i18n_audit("fr")
            local found = false
            for _, k in ipairs(result.missing) do
                if k == testKey then found = true; break end
            end
            assert.is_false(found)
        end)

    end)

    -- ── Version mismatch detection (mock) ────────────────────
    describe("ctld.i18n_audit() version mismatch", function()

        local origVersion

        before_each(function()
            origVersion = ctld.i18n["fr"].translation_version
            ctld.i18n["fr"].translation_version = "0.0"
        end)

        after_each(function()
            ctld.i18n["fr"].translation_version = origVersion
        end)

        it("version_match is false when FR version differs from EN", function()
            local result = ctld.i18n_audit("fr")
            assert.is_false(result.version_match)
        end)

        it("en_version is '1.8'", function()
            local result = ctld.i18n_audit("fr")
            assert.equals("1.8", result.en_version)
        end)

        it("lang_version reflects mocked value '0.0'", function()
            local result = ctld.i18n_audit("fr")
            assert.equals("0.0", result.lang_version)
        end)

        it("version_match is restored to true after mock removed", function()
            ctld.i18n["fr"].translation_version = origVersion
            local result = ctld.i18n_audit("fr")
            assert.is_true(result.version_match)
        end)

    end)

    -- ── auditAll ─────────────────────────────────────────────
    describe("ctld.i18n_auditAll()", function()

        local results

        before_each(function()
            results = ctld.i18n_auditAll()
        end)

        it("returns a table", function()
            assert.equals("table", type(results))
        end)

        it("contains 'fr' entry", function()
            assert.is_not_nil(results["fr"])
        end)

        it("contains 'es' entry", function()
            assert.is_not_nil(results["es"])
        end)

        it("contains 'ko' entry", function()
            assert.is_not_nil(results["ko"])
        end)

        it("does not contain 'en' entry", function()
            assert.is_nil(results["en"])
        end)

        it("each language entry has version_match field", function()
            for _, lang in ipairs({"fr", "es", "ko"}) do
                assert.is_not_nil(results[lang].version_match, lang .. ".version_match")
            end
        end)

        it("each language entry has missing table", function()
            for _, lang in ipairs({"fr", "es", "ko"}) do
                assert.equals("table", type(results[lang].missing), lang .. ".missing")
            end
        end)

        it("each language entry has untranslated table", function()
            for _, lang in ipairs({"fr", "es", "ko"}) do
                assert.equals("table", type(results[lang].untranslated), lang .. ".untranslated")
            end
        end)

    end)

end)
