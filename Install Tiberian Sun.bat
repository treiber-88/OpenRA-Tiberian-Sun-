@echo off
setlocal EnableDelayedExpansion
title Tiberian Sun Installer

powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Welcome to the Tiberian Sun installer.`n`nClick OK to begin.', 'Tiberian Sun Installer', 'OK', 'Information')" >nul 2>&1

REM ── Look for OpenRA playtest first, then stable ──
set "OPENRA="
for %%p in (
    "%ProgramFiles%\OpenRA (playtest)\TiberianDawn.exe"
    "%ProgramFiles(x86)%\OpenRA (playtest)\TiberianDawn.exe"
    "%LocalAppData%\OpenRA (playtest)\TiberianDawn.exe"
    "%LocalAppData%\Programs\OpenRA (playtest)\TiberianDawn.exe"
    "%ProgramFiles%\OpenRA\OpenRA.exe"
    "%ProgramFiles(x86)%\OpenRA\OpenRA.exe"
    "%LocalAppData%\OpenRA\OpenRA.exe"
    "%LocalAppData%\Programs\OpenRA\OpenRA.exe"
) do (
    if exist %%p (
        if not defined OPENRA set "OPENRA=%%~p"
    )
)

if not defined OPENRA (
    powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('OpenRA playtest-20260222 was not found on this computer.`n`nPlease download and install OpenRA playtest first:`nhttps://github.com/OpenRA/OpenRA/releases/tag/playtest-20260222`n`nThen run this installer again.', 'OpenRA Not Found', 'OK', 'Error')"
    exit /b 1
)

REM ── Install mod ──
set "MODDIR=%APPDATA%\OpenRA\mods"
if not exist "%MODDIR%" mkdir "%MODDIR%"

REM Try to install as .oramod package first
if exist "%~dp0ts.oramod" (
    copy /Y "%~dp0ts.oramod" "%MODDIR%\ts.oramod" >nul
) else (
    REM Fall back to installing mod folder
    if not exist "%MODDIR%\ts" mkdir "%MODDIR%\ts"
    xcopy /E /Y /I "%~dp0mods\ts" "%MODDIR%\ts" >nul
)

REM ── Create Desktop shortcut ──
set "WORKDIR=%OPENRA%"
for %%F in ("%OPENRA%") do set "WORKDIR=%%~dpF"

powershell -Command ^
    "$ws = New-Object -ComObject WScript.Shell;" ^
    "$s = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Tiberian Sun.lnk');" ^
    "$s.TargetPath = '%OPENRA%';" ^
    "$s.Arguments = 'Game.Mod=ts';" ^
    "$s.WorkingDirectory = '%WORKDIR%';" ^
    "$s.Description = 'OpenRA - Tiberian Sun';" ^
    "$s.Save()"

powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Tiberian Sun has been installed!`n`nA shortcut has been placed on your Desktop.`n`nThe first time you launch it, you will be prompted to download the free Tiberian Sun game content.', 'Installation Complete', 'OK', 'Information')"
