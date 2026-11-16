# open_ui.ps1 — открывает веб-интерфейс агента после готовности сервера.
# Ждёт доступности порта (до 60 сек), затем открывает интерфейс в отдельном
# окне Chromium-браузера (--app: без вкладок и адресной строки — как приложение).
# Если Chromium-браузеров нет (например, только Firefox) — вкладка браузера по умолчанию.
param(
    [string]$Addr = "127.0.0.1",
    [int]$Port = 38573
)

# Рабочая папка браузера — профиль пользователя, а не папка программы: иначе открытое окно
# браузера «держит» папку bin и её нельзя переименовать или удалить даже после остановки.
$neutralDir = $env:USERPROFILE
if (-not $neutralDir -or -not (Test-Path $neutralDir)) { $neutralDir = $env:SystemRoot }
Set-Location $neutralDir

# 1) Ждём, пока порт начнёт принимать соединения
$connected = $false
for ($i = 0; $i -lt 120; $i++) {
    try {
        $c = New-Object Net.Sockets.TcpClient($Addr, $Port)
        $c.Close()
        $connected = $true
        break
    } catch { Start-Sleep -Milliseconds 500 }
}
$url = "http://${Addr}:${Port}"
if (-not $connected) { Start-Process $url -WorkingDirectory $neutralDir; exit }  # сервер не поднялся за 60 сек — покажем как есть

# 2) Ищем Chromium-браузер (первый найденный)
$browsers = @(
    (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe"),
    (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"),
    (Join-Path $env:LOCALAPPDATA "Yandex\YandexBrowser\Application\browser.exe"),
    (Join-Path $env:ProgramFiles "BraveSoftware\Brave-Browser\Application\brave.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Opera\opera.exe")
)
$exe = $browsers | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($exe) {
    Start-Process $exe -WorkingDirectory $neutralDir -ArgumentList "--app=$url", "--window-size=1280,900", "--no-first-run", "--no-default-browser-check"
} else {
    Start-Process $url -WorkingDirectory $neutralDir  # Chromium нет (Firefox и т.п.) — обычная вкладка браузера по умолчанию
}
