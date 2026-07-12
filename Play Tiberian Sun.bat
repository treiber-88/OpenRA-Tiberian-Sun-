@echo off
setlocal EnableDelayedExpansion

REM ── Prefer the installed OpenRA playtest engine ──
set "ENGINE="
for %%p in (
    "%ProgramFiles%\OpenRA (playtest)\TiberianDawn.exe"
    "%ProgramFiles(x86)%\OpenRA (playtest)\TiberianDawn.exe"
    "%LocalAppData%\OpenRA (playtest)\TiberianDawn.exe"
    "%LocalAppData%\Programs\OpenRA (playtest)\TiberianDawn.exe"
) do (
    if exist %%p (
        if not defined ENGINE set "ENGINE=%%~p"
    )
)

REM ── Fall back to bundled engine ──
if not defined ENGINE set "ENGINE=%~dp0TiberianDawn.exe"

start "" "%ENGINE%" Game.Mod=ts
