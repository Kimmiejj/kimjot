@echo off
cd /d "%~dp0"

where node.exe >nul 2>nul
if errorlevel 1 goto node_missing

start "Kimjod Release Center Server" /min cmd.exe /d /c node.exe release-center\server.js
timeout.exe /t 2 /nobreak >nul
start "" "http://127.0.0.1:4173"
exit /b 0

:node_missing
echo Node.js was not found. Please install Node.js and try again.
pause
exit /b 1
