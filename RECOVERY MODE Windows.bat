@echo off
title PC Security Toolkit - Recovery Mode
echo Opening Recovery Mode. Click Yes on the Windows permission prompt.
set "PSModulePath="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Engine\Recovery.ps1" -Mode Menu
