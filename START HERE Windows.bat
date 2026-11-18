@echo off
title PC Security Toolkit
echo Starting the PC Security Toolkit...
echo Your browser will open by itself. Keep this window open while you use the dashboard.
set "PSModulePath="
if not exist "%~dp0Engine\Toolkit Server.ps1" goto missing
if not exist "%~dp0Engine\Guest Policy.ps1" goto missing
if not exist "%~dp0Engine\Guest Dashboard.html" goto missing
powershell.exe -NoProfile -File "%~dp0Engine\Toolkit Server.ps1"
echo If startup was blocked, respect the device policy and ask its administrator.
pause
exit /b
:missing
echo The toolkit is incomplete. Extract the entire downloaded ZIP into one folder.
pause
exit /b 1
