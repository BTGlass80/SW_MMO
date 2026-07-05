@echo off
title Star Wars MMO Prototype Launcher
echo ===================================================
echo   Star Wars MMO Prototype - Launcher
echo   Inspired by SWG & WEG D6 (Mos Eisley Sandbox)
echo ===================================================
echo.

echo Starting dedicated headless server...
start "SW_MMO Dedicated Server" "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . res://scenes/net_world.tscn -- --server

echo Waiting for server socket initialization...
timeout /t 2 /nobreak > nul

echo Starting client to connect to local server (127.0.0.1)...
start "SW_MMO Client" "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1

echo.
echo Launch sequence complete. Close the dedicated server terminal window when done.
pause
