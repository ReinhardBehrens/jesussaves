@echo off
setlocal
set "DEST=%LOCALAPPDATA%\JesusSaves"
if not exist "%DEST%" mkdir "%DEST%"
for %%F in (JesusSaves.exe JesusSaves.scr SDL2.dll LICENSE SDL2-LICENSE.txt README-Windows.md) do (
  copy /Y "%~dp0%%F" "%DEST%\%%F" >nul
  if errorlevel 1 goto failed
)
if not exist "%DEST%\licenses" mkdir "%DEST%\licenses"
copy /Y "%~dp0licenses\DejaVu.txt" "%DEST%\licenses\DejaVu.txt" >nul
if errorlevel 1 goto failed
rundll32.exe desk.cpl,InstallScreenSaver "%DEST%\JesusSaves.scr"
echo Choose your wait time and sign-in preference in Screen Saver Settings, then Apply.
pause
exit /b 0
:failed
echo Installation failed. Close Jesus Saves if it is running and try again.
pause
exit /b 1
