@echo off
setlocal
set "SPIKE_EXE=%~dp0build\windows\ToTheHumanWorld-Godot-Test.exe"
if not exist "%SPIKE_EXE%" (
  echo Windows test build is missing. See README.md.
  pause
  exit /b 1
)
start "Godot migration test" "%SPIKE_EXE%"
