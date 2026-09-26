@echo off
set "LYNCO_GODOT=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
if not exist "%LYNCO_GODOT%" (
  echo Godot 4.7.1 was not found. Open project.godot with Godot 4.x instead.
  pause
  exit /b 1
)
start "" "%LYNCO_GODOT%" --path "%~dp0."
