# generate_i18n_dicts.ps1
# Scans all src/*.lua files for ctld.tr() calls and synchronises the
# 4 dictionary files (CTLD_i18n_en/fr/es/ko.lua).
#
# Rule: ctld.tr() keys are ALWAYS complete string literals.
# Variable parts use %1, %2 ... placeholders. Never build keys by concatenation.
# This guarantees 100% reliable static scan.
#
# Versioning policy:
#   Each dictionary has its own independent translation_version.
#   Dictionaries are maintained independently, possibly by different people.
#   Each dict's version is bumped when IT is modified (not when others change).
#   ctld.i18n_check() will flag version mismatches as a signal that a dict
#   may be lagging behind EN and needs review.
#
# Modes:
#   Default (no args) : dry-run — reports what would change, writes nothing.
#   -Apply            : applies changes to dict files on disk.
#
# Per-dict changes applied with -Apply:
#   MISSING keys  -> appended at end of file (EN: value=key, others: value="")
#   STALE keys    -> line prefixed with "-- STALE:" (not deleted — confirm manually)
#   version bump  -> each modified dict gets its own version incremented
#
# Usage (from repo root or from build/):
#   .\build\generate_i18n_dicts.ps1           # dry-run
#   .\build\generate_i18n_dicts.ps1 -Apply    # apply

param(
    [switch]$Apply,
    [string]$SourceDir = "",
    [string]$DictDir   = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir

if ($SourceDir -eq "") { $SourceDir = Join-Path $repoRoot "src" }
if ($DictDir   -eq "") { $DictDir   = $SourceDir }

$DictFiles = [ordered]@{
    "en" = (Join-Path $DictDir "CTLD_i18n_en.lua")
    "fr" = (Join-Path $DictDir "CTLD_i18n_fr.lua")
    "es" = (Join-Path $DictDir "CTLD_i18n_es.lua")
    "ko" = (Join-Path $DictDir "CTLD_i18n_ko.lua")
}

$excludeNames = ($DictFiles.Values | ForEach-Object { Split-Path -Leaf $_ }) + @("CTLD_i18n.lua")

Write-Host ""
if ($Apply) {
    Write-Host "=== CTLD i18n dictionary sync — APPLY MODE ===" -ForegroundColor Cyan
} else {
    Write-Host "=== CTLD i18n dictionary sync — DRY RUN (use -Apply to write) ===" -ForegroundColor Yellow
}
Write-Host "Source dir : $SourceDir"
Write-Host ""

# =============================================================================
# Step 1: Collect all ctld.tr() keys from source (excluding dict files)
# =============================================================================
$sourceFiles = Get-ChildItem -Path $SourceDir -Recurse -Filter "*.lua" |
    Where-Object { $excludeNames -notcontains $_.Name }

$usedKeys = [System.Collections.Generic.HashSet[string]]::new()

foreach ($file in $sourceFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    # Keys are ALWAYS complete string literals — no concatenation allowed (see specs/i18n_rules.md)
    $found = [regex]::Matches($content, 'ctld\.tr\s*\(\s*"((?:[^"\\]|\\.)*)"')
    foreach ($m in $found) {
        [void]$usedKeys.Add($m.Groups[1].Value)
    }
}

Write-Host "Keys found via ctld.tr() in source: $($usedKeys.Count)"
Write-Host ""

# =============================================================================
# Helpers
# =============================================================================

function Get-DictKeys([string]$filePath) {
    $keys = [System.Collections.Generic.HashSet[string]]::new()
    if (-not (Test-Path $filePath)) { return $keys }
    $raw = Get-Content $filePath -Raw -Encoding UTF8
    $found = [regex]::Matches($raw, 'ctld\.i18n\["[^"]+"\]\["((?:[^"\\]|\\.)*)"\]')
    foreach ($m in $found) {
        [void]$keys.Add($m.Groups[1].Value)
    }
    return $keys
}

function Get-DictVersion([string]$filePath) {
    $raw = Get-Content $filePath -Raw -Encoding UTF8
    if ($raw -match 'translation_version\s*=\s*"([^"]+)"') { return $Matches[1] }
    return "1.0"
}

function Bump-Version([string]$ver) {
    $parts = $ver.Split('.')
    if ($parts.Length -ge 2) {
        $parts[$parts.Length - 1] = ([int]$parts[$parts.Length - 1] + 1).ToString()
        return ($parts -join '.')
    }
    return $ver
}

# =============================================================================
# Step 2: Process each dict file independently
# =============================================================================
$anyApplied = $false

foreach ($lang in $DictFiles.Keys) {
    $filePath   = $DictFiles[$lang]
    $filename   = Split-Path -Leaf $filePath
    $dictKeys   = Get-DictKeys $filePath
    $currentVer = Get-DictVersion $filePath

    $missing = @($usedKeys | Where-Object { -not $dictKeys.Contains($_) } | Sort-Object)
    $stale   = @($dictKeys  | Where-Object { -not $usedKeys.Contains($_) } | Sort-Object)

    Write-Host "--- $filename ($lang) | version $currentVer ---"

    if ($missing.Count -eq 0 -and $stale.Count -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
        Write-Host ""
        continue
    }

    foreach ($k in $missing) { Write-Host "  MISSING : [$k]" -ForegroundColor Red }
    foreach ($k in $stale)   { Write-Host "  STALE   : [$k]" -ForegroundColor Yellow }

    if (-not $Apply) {
        Write-Host ""
        continue
    }

    # ---- Apply changes ----
    $raw     = Get-Content $filePath -Raw -Encoding UTF8
    $changed = $false

    # Mark stale keys: prefix the matching line with "-- STALE: "
    foreach ($k in $stale) {
        $ek      = [regex]::Escape($k)
        $pattern = "(?m)^(ctld\.i18n\[`"$lang`"\]\[`"$ek`"\].+)$"
        if ([regex]::IsMatch($raw, $pattern)) {
            $raw     = [regex]::Replace($raw, $pattern, '-- STALE: $1')
            $changed = $true
        }
    }

    # Append missing keys at end of file
    if ($missing.Count -gt 0) {
        $date  = (Get-Date).ToString("yyyy-MM-dd")
        $block = "`r`n--- Keys added by generate_i18n_dicts.ps1 on $date`r`n"
        foreach ($k in $missing) {
            if ($lang -eq "en") {
                $block += "ctld.i18n[`"en`"][`"$k`"] = `"$k`"`r`n"
            } else {
                $block += "ctld.i18n[`"$lang`"][`"$k`"] = `"`"`r`n"
            }
        }
        $raw    += $block
        $changed = $true
    }

    # Bump this dict's own version
    if ($changed) {
        $newVer = Bump-Version $currentVer
        $raw    = [regex]::Replace($raw,
            '(translation_version\s*=\s*)"[^"]+"',
            "`$1`"$newVer`"")

        [System.IO.File]::WriteAllText($filePath, $raw, [System.Text.UTF8Encoding]::new($false))
        Write-Host ("  APPLIED : {0} added, {1} staled | {2} -> {3}" -f `
            $missing.Count, $stale.Count, $currentVer, $newVer) -ForegroundColor Cyan
        $anyApplied = $true
    }

    Write-Host ""
}

# =============================================================================
# Summary
# =============================================================================
if (-not $Apply) {
    Write-Host "Dry run complete. Run with -Apply to apply changes." -ForegroundColor Yellow
} elseif ($anyApplied) {
    Write-Host "Sync complete. Fill in empty translations in modified dict files." -ForegroundColor Green
} else {
    Write-Host "All dictionaries are already in sync." -ForegroundColor Green
}
Write-Host ""
