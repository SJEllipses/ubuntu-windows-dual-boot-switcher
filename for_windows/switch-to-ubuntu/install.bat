@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-shortcut-on-desktop.ps1"
if not "%ERRORLEVEL%"=="0" (
    echo [ERROR] Shortcut creation failed.
    pause
    exit /b 1
)

endlocal
exit /b 0