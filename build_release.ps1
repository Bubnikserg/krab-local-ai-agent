# KRAB release builder.
# ВАЖНО: этот файл должен быть сохранён в UTF-8 С BOM — в нём кириллические имена
# файлов, а PowerShell 5.1 без BOM читает их как ANSI и не найдёт.
#
# Usage (from the program folder):
#   powershell -ExecutionPolicy Bypass -File build_release.ps1                 # code-only update
#   powershell -ExecutionPolicy Bypass -File build_release.ps1 -ToolsUpdated   # python/Tesseract changed
#
# Produces in the program folder (attach these three files to the GitHub Release):
#   KRAB-update.zip                - code only (light auto-update)
#   KRAB-<version>-windows-x64.zip - full archive (code + python + Tesseract)
#   update.json                    - release manifest for the updater
param([switch]$ToolsUpdated)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$ver = ""
try {
    $ver = (Get-Content -LiteralPath (Join-Path $root "bin\version.json") -Raw | ConvertFrom-Json).version
} catch { $ver = "" }
if (-not $ver) { throw "Cannot read version from bin\version.json" }
Write-Host ("Building KRAB " + $ver + " (tools_updated: " + [bool]$ToolsUpdated + ")")

# --- whitelist: в релиз попадает ТОЛЬКО перечисленное здесь ---
# Всё остальное в папке (история чата, кэши, тесты, служебные файлы) в релиз не входит.
# Новый файл программы = новая строка в этом списке (осознанное действие).
$rootFiles = @(
    "README.md",
    "LICENSE",
    "THIRD-PARTY-NOTICES.md",
    "Запуск.bat",
    "ИНСТРУКЦИЯ.html"
)
$binFiles = @(
    "app.py",
    "index.html",
    "tools.py",
    "sandbox_guard.py",
    "run.bat",
    "run_hidden.vbs",
    "stop.vbs",
    "make_shortcut.ps1",
    "open_ui.ps1",
    "krab.ico",
    "version.json",
    ".env.example",
    "requirements.txt",
    "model_descriptions.json",
    "update_model_descriptions.py"
)

# --- staging: чистая копия программы в том виде, как она поставляется ---
$stage = Join-Path $env:TEMP ("krab_release_" + $ver)
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage "bin") | Out-Null

$missing = @()
foreach ($f in $rootFiles) {
    $p = Join-Path $root $f
    if (Test-Path -LiteralPath $p -PathType Leaf) { Copy-Item -LiteralPath $p -Destination $stage }
    else { $missing += $f }
}
foreach ($f in $binFiles) {
    $p = Join-Path $root ("bin\" + $f)
    if (Test-Path -LiteralPath $p -PathType Leaf) { Copy-Item -LiteralPath $p -Destination (Join-Path $stage "bin") }
    else { $missing += ("bin\" + $f) }
}
if ($missing.Count -gt 0) { throw ("Отсутствуют файлы релиза: " + ($missing -join ", ")) }

# --- лёгкий zip обновления (только код) ---
$lightZip = Join-Path $root "KRAB-update.zip"
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $lightZip -Force
Write-Host ("  " + $lightZip)

# --- полный архив: staging + переносимые python и Tesseract ---
Copy-Item -LiteralPath (Join-Path $root "bin\python") (Join-Path $stage "bin\python") -Recurse
Copy-Item -LiteralPath (Join-Path $root "bin\Tesseract-OCR") (Join-Path $stage "bin\Tesseract-OCR") -Recurse
$fullZip = Join-Path $root ("KRAB-" + $ver + "-windows-x64.zip")
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $fullZip -Force
Write-Host ("  " + $fullZip)

# --- манифест для ассетов релиза ---
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
