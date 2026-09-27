@echo off
set "LYNCO_GODOT=C:\Users\user\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
if not exist "%LYNCO_GODOT%" (
 echo Godot executable not found. Update LYNCO_GODOT in this file.
 pause
 exit /b 1
)
start "" "%LYNCO_GODOT%" --path "%~dp0"