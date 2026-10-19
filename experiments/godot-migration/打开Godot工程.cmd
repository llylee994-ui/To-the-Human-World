@echo off
setlocal
set "GODOT_SPIKE_EDITOR=%USERPROFILE%\.codex\tools\godot\4.7.2-stable\editor\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_SPIKE_EDITOR%" (
  echo Portable Godot is missing. Run tools\setup_godot.py first.
  pause
  exit /b 1
)
start "Godot migration project" "%GODOT_SPIKE_EDITOR%" --editor --path "%~dp0."
