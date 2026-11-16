# KRAB release builder.
# Usage (from the program folder):
#   powershell -ExecutionPolicy Bypass -File build_release.ps1                 # code-only update
#   powershell -ExecutionPolicy Bypass -File build_release.ps1 -ToolsUpdated   # python/Tesseract changed
#
# Produces in the program folder (these three files are attached to the GitHub Release):
#   KRAB-update.zip               - code only (light auto-update)
#   KRAB-<version>-windows-x64.zip - full archive (code + python + Tesseract)
#   update.json                   - release manifest for the updater
param([switch]$ToolsUpdated)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$ver = ""
try {
    $ver = (Get-Content -LiteralPath (Join-Path $root "bin\version.json") -Raw | ConvertFrom-Json).version
} catch { $ver = "" }
if (-not $ver) { throw "Cannot read version from bin\version.json" }
Write-Host ("Building KRAB " + $ver + " (tools_updated: " + [bool]$ToolsUpdated + ")")

# --- staging: a clean copy of the program as it ships ---
$stage = Join-Path $env:TEMP ("krab_release_" + $ver)
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage "bin") | Out-Null

# root files: everything except user data, binaries and build outputs
$skipRoot = @("workspace", "docs", "bin", ".git")
Get-ChildItem -LiteralPath $root -Force -File | Where-Object {
    $n = $_.Name
    ($skipRoot -notcontains $n) -and
    ($n -notlike "*.lnk") -and ($n -notlike "KRAB-*.zip") -and
    ($n -ne "update.json") -and ($n -ne "proxy.txt")
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stage }

# bin files: code and small assets only (python/Tesseract/logs/user data excluded)
$skipBin = @("python", "Tesseract-OCR", "logs", "__pycache__", ".env", ".desktop_shortcut_done")
Get-ChildItem -LiteralPath (Join-Path $root "bin") -Force | Where-Object {
    $skipBin -notcontains $_.Name
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stage "bin") -Recurse }

# --- light update zip (code only) ---
$lightZip = Join-Path $root "KRAB-update.zip"
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $lightZip -Force
Write-Host ("  " + $lightZip)

# --- full archive: staging + portable python + tesseract ---
Copy-Item -LiteralPath (Join-Path $root "bin\python") (Join-Path $stage "bin\python") -Recurse
Copy-Item -LiteralPath (Join-Path $root "bin\Tesseract-OCR") (Join-Path $stage "bin\Tesseract-OCR") -Recurse
$fullZip = Join-Path $root ("KRAB-" + $ver + "-windows-x64.zip")
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $fullZip -Force
Write-Host ("  " + $fullZip)

# --- manifest for the release assets ---
$manifest = @{
    version       = $ver
    tools_updated = [bool]$ToolsUpdated
    notes         = ""
}
$manifestPath = Join-Path $root "update.json"
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host ("  " + $manifestPath)

Remove-Item $stage -Recurse -Force
Write-Host "Done. Attach these three files to the GitHub Release."
