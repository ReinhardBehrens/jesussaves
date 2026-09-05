@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
if errorlevel 1 (
  echo.
  echo Installation failed. Extract the full ZIP and close Jesus Saves before retrying.
  pause
  exit /b 1
)
echo.
echo Jesus Saves is selected and enabled. You can adjust the wait time in Windows settings.
pause
