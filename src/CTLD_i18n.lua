--[[
    CTLD — Internationalization class (CTLDi18n)
    src version — logic only, no dictionary data.

    Dictionary files (loaded after this file):
        CTLD_i18n_en.lua  — English reference (keys and EN text)
        CTLD_i18n_fr.lua  — French
        CTLD_i18n_es.lua  — Spanish
        CTLD_i18n_ko.lua  — Korean

    To add a new language: create CTLD_i18n_XX.lua following the EN template,
    add it to tools/build/listToMerge.txt, and regenerate the loader.

    Translators: edit only the CTLD_i18n_XX.lua files. Never edit this file.
    Run tools/build/generate_i18n_dicts.ps1 after any ctld.tr() change in scripts.
]]

if not ctld then ctld = {} end
ctld.i18n = ctld.i18n or {}

-- =====================================================================
-- Active language selector
-- Uncomment the language you want to use.
-- =====================================================================
ctld.i18n_lang = "en"
--ctld.i18n_lang = "fr"
--ctld.i18n_lang = "es"
--ctld.i18n_lang = "ko"

-- =====================================================================
-- CTLDi18n singleton
-- =====================================================================
CTLDi18n = {}
CTLDi18n._instance = nil

function CTLDi18n.getInstance()
    if not CTLDi18n._instance then
        CTLDi18n._instance = setmetatable({}, { __index = CTLDi18n })
        CTLDi18n._instance:_init()
    end
    return CTLDi18n._instance
end

--- Apply mission-maker overrides declared in CTLD_userConfig.lua.
--- Called once at startup by getInstance().
function CTLDi18n:_init()
    if ctld.i18n_overrides then
        for lang, entries in pairs(ctld.i18n_overrides) do
            if ctld.i18n[lang] then
                for key, value in pairs(entries) do
                    ctld.i18n[lang][key] = value
                end
            end
        end
    end
end

-- =====================================================================
-- Translation function
-- =====================================================================

--- Translate a string to the active language, with optional parameter substitution.
--- Fallback chain: active lang → EN → key itself (never empty, never nil).
---@param text string The key to translate (= the English text)
---@param ... any Parameters to substitute for %1, %2, ... placeholders
---@return string
function ctld.tr(text, ...)
    local _text

    if not ctld.i18n[ctld.i18n_lang] then
        ctld.utils.log("WARN", "CTLDi18n.tr: language '%s' not found, defaulting to 'en'",
            tostring(ctld.i18n_lang))
        _text = ctld.i18n["en"][text]
    else
        _text = ctld.i18n[ctld.i18n_lang][text]
    end

    -- Fallback to English
    if _text == nil then
        _text = ctld.i18n["en"][text]
    end

    -- Final fallback: use the key itself (= the English text)
    if _text == nil or _text == "" then
        _text = text
    end

    -- Parameter substitution (%1, %2, ...)
    local args = { ... }
    if #args > 0 then
        for i, v in ipairs(args) do
            _text = string.gsub(_text, "%%" .. i, tostring(v))
        end
    end

    return _text
end

--- Backward-compatibility alias.
ctld.i18n_translate = ctld.tr

-- =====================================================================
-- Dictionary integrity checker
-- =====================================================================

--- Audit a language dictionary against EN.
--- Returns a structured result table suitable for assertions in tests or scripts.
--- Does NOT write to env.* — callers decide how to display/log the result.
---@param language string Language code to audit (e.g. "fr")
---@return table|nil result  { version_match=bool, en_version=str, lang_version=str, missing={}, untranslated={} }
---@return string|nil err    non-nil when the language is unknown
function ctld.i18n_audit(language)
    local english = ctld.i18n["en"]
    local tocheck = ctld.i18n[language]
    if not tocheck then
        return nil, string.format("CTLDi18n.audit: language '%s' not found", tostring(language))
    end
    local enVer   = english.translation_version or "?"
    local langVer = tocheck.translation_version or "?"
    local result  = {
        version_match = (enVer == langVer),
        en_version    = enVer,
        lang_version  = langVer,
        missing       = {},
        untranslated  = {},
    }
    for key, enVal in pairs(english) do
        if key ~= "translation_version" then
            local langVal = tocheck[key]
            if langVal == nil then
                result.missing[#result.missing + 1] = key
            elseif langVal == enVal then
                result.untranslated[#result.untranslated + 1] = key
            end
        end
    end
    return result
end

--- Audit all non-English dictionaries in one call.
--- @return table  { [lang] = audit_result, ... }  one entry per loaded non-EN language
function ctld.i18n_auditAll()
    local results = {}
    for lang in pairs(ctld.i18n) do
        if lang ~= "en" then
            results[lang] = ctld.i18n_audit(lang)
        end
    end
    return results
end

--- Check that a language dictionary is complete and version-compatible with EN.
--- Logs errors for missing keys and warnings for untranslated entries.
---@param language string Language code to check (e.g. "fr")
---@param verbose boolean If true, log each passing entry as well
function ctld.i18n_check(language, verbose)
    local english = ctld.i18n["en"]
    local tocheck = ctld.i18n[language]
    if not tocheck then
        env.error(string.format("CTLDi18n.i18n_check: language '%s' not found", language))
        return false
    end

    local englishVersion = english.translation_version
    local tocheckVersion = tocheck.translation_version
    if englishVersion ~= tocheckVersion then
        env.error(string.format(
            "CTLDi18n.i18n_check: version mismatch — EN is %s, %s is %s",
            englishVersion, language, tocheckVersion))
    end

    for textRef, textEnglish in pairs(english) do
        if textRef ~= "translation_version" then
            local textTocheck = tocheck[textRef]
            if not textTocheck then
                env.error(string.format(
                    "CTLDi18n.i18n_check: MISSING in %s: [%s]", language, textRef))
            elseif textTocheck == textEnglish then
                env.warning(string.format(
                    "CTLDi18n.i18n_check: UNTRANSLATED in %s: [%s]", language, textRef))
            elseif verbose then
                ctld.utils.log("INFO", "CTLDi18n.i18n_check: OK in %s: [%s]", language, textRef)
            end
        end
    end
end

-- =====================================================================
-- Translator audit helper — call from a DO SCRIPT trigger (dev/QA only)
-- =====================================================================
--[[
-- Run after CTLD_Next.lua to get a per-language gap report in DCS.log:
--
--   local results = ctld.i18n_auditAll()
--   for lang, r in pairs(results) do
--       local lines = { string.format(
--           "=== i18n audit: lang=%s  EN_v=%s  lang_v=%s  version_match=%s",
--           lang, r.en_version, r.lang_version, tostring(r.version_match)) }
--       if #r.missing > 0 then
--           lines[#lines+1] = string.format("  MISSING (%d):", #r.missing)
--           for _, k in ipairs(r.missing) do
--               lines[#lines+1] = "    - " .. k
--           end
--       end
--       if #r.untranslated > 0 then
--           lines[#lines+1] = string.format("  UNTRANSLATED (%d):", #r.untranslated)
--           for _, k in ipairs(r.untranslated) do
--               lines[#lines+1] = "    ~ " .. k
--           end
--       end
--       if #r.missing == 0 and #r.untranslated == 0 then
--           lines[#lines+1] = "  All entries translated."
--       end
--       env.info(table.concat(lines, "\n"))
--   end
--]]
