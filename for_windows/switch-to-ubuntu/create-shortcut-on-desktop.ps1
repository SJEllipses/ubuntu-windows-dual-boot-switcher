#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        throw 'Could not determine the script directory.'
    }

    $batPath = Join-Path -Path $scriptDir -ChildPath 'switch-to-ubuntu.bat'
    $iconPath = Join-Path -Path $scriptDir -ChildPath 'ubuntu.ico'

    if (-not (Test-Path -LiteralPath $batPath -PathType Leaf)) {
        throw "Required file not found: $batPath"
    }
    if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
        throw "Required icon not found: $iconPath"
    }

    $desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop -PathType Container)) {
        throw 'Could not locate the current user''s Desktop folder.'
    }

    $shortcutPath = Join-Path -Path $desktop -ChildPath 'Switch to Ubuntu.lnk'
    $shell = New-Object -ComObject 'WScript.Shell'
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $env:SystemRoot -ChildPath 'System32\cmd.exe'
    $shortcut.Arguments = '/c switch-to-ubuntu.bat'
    $shortcut.WorkingDirectory = $scriptDir
    $shortcut.IconLocation = "$iconPath,0"
    $shortcut.Description = 'Boot directly into Ubuntu on the next restart'
    $shortcut.WindowStyle = 1
    $shortcut.Save()

    if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
        throw "Shortcut was not created: $shortcutPath"
    }

    Write-Host "Created desktop shortcut: $shortcutPath"
    exit 0
}
catch {
    Write-Error $_
    exit 1
}