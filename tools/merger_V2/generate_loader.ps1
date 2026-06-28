# Generate CTLD_loader.lua from merger_V2/listToMerge.txt
# Source of truth: listToMerge.txt
# Output: CTLD_loader.lua at repo root

$mergerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $mergerDir
$listFile  = Join-Path $mergerDir "listToMerge.txt"
$outFile   = Join-Path $repoRoot "CTLD_loader.lua"

if (-not (Test-Path $listFile)) {
    Write-Error "[ERROR] listToMerge.txt not found at: $listFile"
    exit 1
}

$lines = [System.Collections.Generic.List[string]]::new()

$lines.Add("---@diagnostic disable")
$lines.Add("-- CTLD Dev Loader")
$lines.Add("-- Auto-generated from merger_V2/listToMerge.txt - DO NOT EDIT MANUALLY")
$lines.Add("-- Regenerate with: powershell -ExecutionPolicy Bypass -File tools/merger_V2/generate_loader.ps1")
$lines.Add("--")
$lines.Add("-- HOW TO USE:")
$lines.Add("--   1. Set CTLD_SOURCE_PATH to the absolute path of your src/ directory.")
$lines.Add("--   2. Use forward slashes. End with a trailing slash.")
$lines.Add("--   3. In your DCS mission trigger: dofile('absolute/path/to/CTLD_loader.lua')")
$lines.Add("")
$lines.Add("local CTLD_SOURCE_PATH = ""C:/replace/with/your/absolute/path/to/src/""  -- CONFIGURE THIS")
$lines.Add("")

foreach ($rawLine in Get-Content $listFile -Encoding UTF8) {
    $trimmed = $rawLine.Trim()

    if ($trimmed -eq "") {
        $lines.Add("")
    }
    elseif ($trimmed.StartsWith("--")) {
        $lines.Add($trimmed)
    }
    else {
        $lines.Add("dofile(CTLD_SOURCE_PATH .. """ + $trimmed + """)")
    }
}

[System.IO.File]::WriteAllLines($outFile, $lines, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Generated: $outFile"
Write-Host "Remember to set CTLD_SOURCE_PATH before using the loader in DCS."
