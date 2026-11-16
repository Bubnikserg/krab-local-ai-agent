@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0"

rem ==========================================================================
rem  KRAB - start with a VISIBLE console (diagnostics: live server output).
rem  Normal start: launcher bat in the program root folder (no console window).
rem  Use this file only to see errors; the log is also in bin\logs\agent.log.
rem  Usage: run.bat [nobrowser]
rem ==========================================================================

if not exist "python\python.exe" (
    echo [ERROR] bin\python\python.exe not found.
    echo         The program folder is incomplete - unpack the KRAB archive again.
    pause
    exit /b 1
)

rem ---- HOST/PORT from bin\.env (defaults: 127.0.0.1 / 8000) ----
set "HOST=127.0.0.1"
set "PORT=8000"
if exist ".env" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
        if /i "%%A"=="HOST" set "HOST=%%B"
        if /i "%%A"=="PORT" set "PORT=%%B"
    )
)
set "HOST=!HOST: =!"
set "PORT=!PORT: =!"
set "UIHOST=!HOST!"
if "!HOST!"=="0.0.0.0" set "UIHOST=127.0.0.1"

if not exist "..\workspace" mkdir "..\workspace"
if not exist "logs" mkdir "logs"

echo ================================================
echo  KRAB: http://!UIHOST!:!PORT!
echo  Close this window or press Ctrl+C to stop.
echo ================================================

rem ---- Open the UI only when the port is actually up (max ~60 s wait) ----
if /i not "%~1"=="nobrowser" start "" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open_ui.ps1" -Addr !UIHOST! -Port !PORT!

rem ---- Isolation: use ONLY bundled Python packages (ignore user/system site-packages) ----
set "PYTHONNOUSERSITE=1"
set "PYTHONPATH="
set "PYTHONIOENCODING=utf-8"
"python\python.exe" -s -m uvicorn app:app --host !HOST! --port !PORT!

echo.
echo [INFO] Server stopped.
pause
