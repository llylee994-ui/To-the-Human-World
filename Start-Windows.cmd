@echo off
cd /d "%~dp0"
where py >nul 2>nul
if not errorlevel 1 (
    py -3 "%~dp0tools\run_windows_game.py" %*
) else (
    python "%~dp0tools\run_windows_game.py" %*
)
if errorlevel 1 pause
