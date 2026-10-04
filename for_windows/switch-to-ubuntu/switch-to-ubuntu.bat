@echo off
setlocal EnableExtensions

echo Setting next boot to Ubuntu...

fltmc >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo Requesting administrator privileges...
    set "SWITCH_TO_UBUNTU_BAT=%~f0"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "if ([string]::IsNullOrEmpty($env:SWITCH_TO_UBUNTU_BAT)) { exit 2 }; try { Start-Process -FilePath $env:SWITCH_TO_UBUNTU_BAT -Verb RunAs } catch { exit 1 }"
    if errorlevel 1 (
        echo [ERROR] Administrator privileges were not granted.
        exit /b 1
    )
    exit /b 0
)

rem Try every normal drive letter. Letters already in use make mountvol fail;
rem unavailable removable/network letters are therefore skipped automatically.
set "ESP="
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined ESP (
        mountvol %%D: /S >nul 2>&1
        if not errorlevel 1 (
            if exist "%%D:\EFI\ubuntu\" (
                set "ESP=%%D:"
            ) else (
                echo [ERROR] The EFI System Partition was mounted as %%D:, but EFI\ubuntu was not found.
                mountvol %%D: /D >nul 2>&1
                pause
                exit /b 1
            )
        )
    )
)

if not defined ESP (
    echo [ERROR] Could not assign a free drive letter to the EFI System Partition.
    echo Check that this PC uses an Ubuntu-style ESP layout ^(EFI\ubuntu^), then retry.
    pause
    exit /b 1
)

set "FLAG_PATH=%ESP%\EFI\ubuntu\switch.flag"
echo boot-once>"%FLAG_PATH%" 2>nul
if not exist "%FLAG_PATH%" (
    echo [ERROR] Could not create %FLAG_PATH%.
    mountvol "%ESP%" /D >nul 2>&1
    pause
    exit /b 1
)

echo Created %FLAG_PATH%.

mountvol "%ESP%" /D >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo [ERROR] The boot flag was created, but ESP drive %ESP% could not be dismounted.
    pause
    exit /b 1
)

echo Rebooting...
shutdown /r /t 0
if not "%ERRORLEVEL%"=="0" (
    echo [ERROR] Windows rejected the shutdown request.
    pause
    exit /b 1
)

endlocal
exit /b 0
