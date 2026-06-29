# CTLD i18n — Rules and conventions

## ctld.tr() key format

**Rule: the key passed to `ctld.tr()` is ALWAYS a complete string literal.**

Variable parts are expressed with `%1`, `%2`, ... placeholders inside the literal.
Dynamic values are passed as separate arguments after the key.

```lua
-- CORRECT
ctld.tr("Sorry you must wait %1 seconds before you can get another crate", waitTime)
ctld.tr("%1 loaded %2 vehicles into %3", pilotName, count, zoneName)

-- FORBIDDEN — key built by concatenation (breaks static scan)
ctld.tr("prefix_" .. suffix)
ctld.tr(someVariable)
```

**Why this matters:** `generate_i18n_dicts.ps1` scans source files with a regex to extract
all translation keys. If the key is always a string literal, the scan is 100% reliable
with no blind spots. Breaking this rule causes keys to be silently missing from the dicts.

## translation_version

- Stored as a string field in each dict: `ctld.i18n["en"].translation_version`
- Version format: `"MAJOR.MINOR"` (e.g. `"1.7"`).
- **Each dictionary has its own independent version.**
  Dicts are maintained independently, possibly by different translators at different times.
  `generate_i18n_dicts.ps1 -Apply` bumps each modified dict's own version independently.
- `ctld.i18n_check(lang)` flags a version mismatch between EN and another lang as a warning.
  This is a useful signal: it tells a translator their dict may lag behind EN and needs review.
  It does NOT block usage — the fallback chain handles missing keys gracefully.
- History (EN):
  - `"1.6"` — original source version
  - `"1.7"` — added "Pack Vehicles" key (pack → pack rename)

## Dict file responsibilities

| File | Role |
|---|---|
| `CTLD_i18n.lua` | Class logic only: `ctld.tr()`, `ctld.i18n_check()`, `CTLDi18n` singleton. No dict data. |
| `CTLD_i18n_en.lua` | English reference. Values = keys (explicit text). Never empty. |
| `CTLD_i18n_fr.lua` | French. Empty value `""` = untranslated (falls back to EN). |
| `CTLD_i18n_es.lua` | Spanish. Same rule. |
| `CTLD_i18n_ko.lua` | Korean. Same rule. |

## Fallback chain (ctld.tr behaviour)

1. Active language dict (`ctld.i18n_lang`)
2. English dict
3. The key itself (= the English text)

A translation is **never** nil or empty in the returned string.

## Mission-maker overrides

MMs can override any key without touching dict files, via `CTLD_userConfig.lua`:

```lua
ctld.i18n_overrides = {
    fr = { ["Pack Vehicles"] = "Empaqueter vehicules" },
    en = { ["CTLD Commands"] = "Helicopter Commands" },
}
```

Overrides are applied at startup by `CTLDi18n:_init()`.

## generate_i18n_dicts.ps1 usage

```powershell
# Audit only (no file changes)
.\build\generate_i18n_dicts.ps1

# Apply changes (add missing keys, mark stales, bump version)
.\build\generate_i18n_dicts.ps1 -Apply
```

Run after any `ctld.tr()` addition or removal in source scripts.
