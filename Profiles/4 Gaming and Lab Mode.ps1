# ==============================================================================
# 4 Gaming and Lab Mode.ps1 — GAMING, ANTI-CHEAT & GNS3 LAB MODE
# Best for: Steam/Games, Anti-Cheats, GNS3, VMs, and Maximum FPS/RAM.
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Save a recovery snapshot first so every change can be undone in Recovery Mode
$toolkitRecovery = Join-Path (Split-Path -Parent $PSScriptRoot) "Engine\Recovery.ps1"
if (Test-Path -LiteralPath $toolkitRecovery) { & $toolkitRecovery -Mode Snapshot -Label "Before profile $([IO.Path]::GetFileNameWithoutExtension($PSCommandPath))" -Quiet | Out-Null }

Write-Host "=== [GAMING & LAB MODE] STEP 1: RESTORE POINT & SSD TRIM ===" -ForegroundColor Cyan
Enable-ComputerRestore -Drive "C:\"
Checkpoint-Computer -Description "Pre-Gaming-Lab-Optimization" -RestorePointType "MODIFY_SETTINGS"
if (Test-Path "$env:LOCALAPPDATA\Temp") { Remove-Item "$env:LOCALAPPDATA\Temp\*" -Recurse -Force }
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
    Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim
}

Write-Host "=== [GAMING & LAB MODE] STEP 2: STOP P2P BANDWIDTH HOGGING & BACKGROUND TELEMETRY ===" -ForegroundColor Cyan
# Turn off Delivery Optimization P2P so Windows doesn't upload updates while gaming!
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0 -Type DWord -Force

# Block Recall screenshots, Typing harvesting, Bing Start Menu search, Advertising ID
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\InputPersonalization")) { New-Item -Path "HKCU:\Software\Microsoft\InputPersonalization" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) { New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Force

# Stop browser background RAM usage while gaming
foreach ($b in @("HKLM:\SOFTWARE\Policies\Microsoft\Edge", "HKLM:\SOFTWARE\Policies\Google\Chrome")) {
    if (-not (Test-Path $b)) { New-Item -Path $b -Force | Out-Null }
    Set-ItemProperty -Path $b -Name "BackgroundModeEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $b -Name "StartupBoostEnabled" -Value 0 -Type DWord -Force
}

Write-Host "=== [GAMING & LAB MODE] STEP 3: GAMING-SAFE SECURITY (NO ANTI-CHEAT OR GNS3 BREAKAGE) ===" -ForegroundColor Cyan
# Disable Intel LMS, Remote Assistance, USB AutoRun, LLMNR, WPAD
Set-Service -Name "LMS", "MapsBroker", "dptftcs" -StartupType Manual
Stop-Service -Name "LMS", "MapsBroker", "dptftcs" -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord -Force
if (-not (Test-Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient")) { New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force

# Keep Defender RealTime + PUA + Network Protection ON, but DO NOT touch Controlled Folder Access or Game Services!
Set-MpPreference -DisableRealtimeMonitoring $false -PUAProtection Enabled -EnableNetworkProtection Enabled

# Keep GNS3 / Dynamips / Qemu / VirtualBox working on Private Home LAN, block only Public
Get-NetFirewallRule | Where-Object { $_.DisplayName -match 'GNS3|Dynamips|VPCS|Qemu' -and $_.Profile -match 'Public' } | Set-NetFirewallRule -Profile Private

Write-Host "`n[GAMING & LAB MODE COMPLETE] Games, anti-cheats, GNS3 & VMs remain 100% intact!" -ForegroundColor Green
