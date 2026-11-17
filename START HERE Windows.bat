@echo off
title PC Security Toolkit
echo Starting the PC Security Toolkit...
echo Your browser will open by itself. Keep this window open while you use the dashboard.
set "PSModulePath="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Engine\Toolkit Server.ps1"
pause
