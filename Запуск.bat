@echo off
rem ==========================================================================
rem  KRAB - normal launcher (double-click this file).
rem  On first run (and after each update) it removes the "downloaded from
rem  internet" mark from the program files and creates the shortcuts,
rem  then hands over to bin\run_hidden.vbs (no console window is kept).
rem  Daily use: the shortcuts created in this folder and on the desktop.
rem ==========================================================================
cd /d "%~dp0"
chcp 65001 >nul
echo KRAB: запускаюсь... Первый запуск может занять около минуты (подготовка папки), это окно закроется само.
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0bin\make_shortcut.ps1"
start "" wscript.exe "%~dp0bin\run_hidden.vbs"
exit
