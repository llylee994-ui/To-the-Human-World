@echo off
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 goto usepy
python -B "scripts\layout-editor\panel_materials.py"
if errorlevel 1 pause
exit /b
:usepy
where py >nul 2>nul
if errorlevel 1 goto missing
py -3 -B "scripts\layout-editor\panel_materials.py"
if errorlevel 1 pause
exit /b
:missing
echo Python 3.10 or newer is required.
pause
