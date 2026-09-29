@echo off
REM Double-click this file to start InfraVision and open it in Chrome.
REM It installs dependencies on the first run, then leaves the dev server
REM running in this window. Close the window or press Ctrl+C to stop.

setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo   Node.js is not installed, or is not on your PATH.
  echo   Install the LTS build from https://nodejs.org and run this again.
  echo.
  pause
  exit /b 1
)

echo.
echo   Starting InfraVision...
echo   Leave this window open while you use the app.
echo.

call npm run launch

echo.
echo   InfraVision has stopped. Close this window, or press any key to exit.
pause >nul
