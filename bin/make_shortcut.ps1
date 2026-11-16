# Подготовка ярлыков и снятие пометки «загружено из интернета» (Zone.Identifier).
# Вызывается при каждом запуске программы (из run_hidden.vbs и Запуск.bat):
#   1) если у файлов стоит пометка «загружено из интернета» (появляется, когда скачанный
#      архив распакован Проводником) — снимает её: именно из-за этой пометки Windows
#      задаёт вопросы о запуске скриптов и python.exe. Критичные для старта файлы
#      разбираются сразу, остальные (десятки тысяч) — в фоне, не задерживая старт;
#   2) создаёт ярлыки «КРАБ - Запуск» и «КРАБ - Стоп» в папке программы (со значком
#      краба) и ярлык «КРАБ» на рабочем столе; при переносе папки пути исправляются;
#   3) удаляет устаревшие файлы запуска прежних версий (СТАРТ.vbs, СТОП.vbs, Стоп.bat).
$ErrorActionPreference = "SilentlyContinue"

$bin     = $PSScriptRoot
$root    = Split-Path -Parent $bin
$ws      = New-Object -ComObject WScript.Shell
$wscript = Join-Path $env:SystemRoot "System32\wscript.exe"
$ico     = Join-Path $bin "krab.ico"

$iconRun  = if (Test-Path -LiteralPath $ico) { "$ico,0" } else { "$wscript,0" }
$iconStop = if (Test-Path -LiteralPath $ico) { "$ico,0" } else { "$wscript,1" }
$argsRun  = '"' + (Join-Path $bin "run_hidden.vbs") + '"'
$argsStop = '"' + (Join-Path $bin "stop.vbs") + '"'

# --- 1. Пометка «загружено из интернета» ---
$probe = Join-Path $bin "krab.ico"
$hasZone = $false
try { $hasZone = [bool](Get-Item -LiteralPath $probe -Stream Zone.Identifier -ErrorAction Stop) } catch { $hasZone = $false }
if ($hasZone) {
    foreach ($f in @("run_hidden.vbs", "stop.vbs", "make_shortcut.ps1", "open_ui.ps1", "run.bat", "krab.ico",
                     "python\python.exe", "python\pythonw.exe", "Tesseract-OCR\tesseract.exe")) {
        Unblock-File -LiteralPath (Join-Path $bin $f) -ErrorAction SilentlyContinue
    }
    $cmd = "Get-ChildItem -LiteralPath '" + $root.Replace("'", "''") + "' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    Start-Process -FilePath "powershell.exe" -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $enc"
}

# --- 2. Ярлыки ---
function Set-Shortcut($path, $arguments, $description, $icon) {
    $sc = $ws.CreateShortcut($path)
    if ((Test-Path -LiteralPath $path) -and $sc.TargetPath -eq $wscript -and $sc.Arguments -eq $arguments -and
        $sc.WorkingDirectory -eq $bin -and $sc.IconLocation -eq $icon) {
        return   # ярлык в порядке — не переписываем
    }
    $sc.TargetPath       = $wscript
    $sc.Arguments        = $arguments
    $sc.WorkingDirectory = $bin
    $sc.Description      = $description
    $sc.IconLocation     = $icon
    $sc.WindowStyle      = 7   # свёрнуто: wscript окна не показывает, но пусть и не мелькает
    $sc.Save()
}

# В папке программы — часть комплекта: создаются при каждом запуске и самовосстанавливаются.
Set-Shortcut (Join-Path $root "КРАБ - Запуск.lnk") $argsRun "Запуск КРАБ" $iconRun
Set-Shortcut (Join-Path $root "КРАБ - Стоп.lnk")   $argsStop "Остановка КРАБ" $iconStop

# На рабочем столе — по желанию пользователя: создаётся один раз, при переносе
# папки исправляется, удалённый пользователем ярлык не возвращается.
$desktop = Join-Path ([Environment]::GetFolderPath("Desktop")) "КРАБ.lnk"
$marker  = Join-Path $bin ".desktop_shortcut_done"
if (Test-Path -LiteralPath $desktop) {
    Set-Shortcut $desktop $argsRun "КРАБ" $iconRun
} elseif (-not (Test-Path -LiteralPath $marker)) {
    Set-Shortcut $desktop $argsRun "КРАБ" $iconRun
    Set-Content -LiteralPath $marker -Value (Get-Date -Format s) -Encoding ASCII
}

# --- 3. Устаревшие файлы запуска прежних версий ---
Remove-Item -LiteralPath (Join-Path $root "СТАРТ.vbs") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $root "СТОП.vbs")  -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $root "Стоп.bat")  -Force -ErrorAction SilentlyContinue
