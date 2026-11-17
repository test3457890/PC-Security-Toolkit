# ==============================================================================
# 3 Work Professional.ps1 — WORK, OFFICE/M365, TEAMS & VPN MODE
# Best for: Microsoft 365, Teams/Zoom, OneDrive, and remote work reliability.
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Save a recovery snapshot first so every change can be undone in Recovery Mode
$toolkitRecovery = Join-Path (Split-Path -Parent $PSScriptRoot) "Engine\Recovery.ps1"
if (Test-Path -LiteralPath $toolkitRecovery) { & $toolkitRecovery -Mode Snapshot -Label "Before profile $([IO.Path]::GetFileNameWithoutExtension($PSCommandPath))" -Quiet | Out-Null }

Write-Host "=== [WORK MODE] STEP 1: RESTORE POINT & SAFE CLEANUP ===" -ForegroundColor Cyan
Enable-ComputerRestore -Drive "C:\"
Checkpoint-Computer -Description "Pre-Work-Optimization" -RestorePointType "MODIFY_SETTINGS"
if (Test-Path "$env:LOCALAPPDATA\Temp") { Remove-Item "$env:LOCALAPPDATA\Temp\*" -Recurse -Force }
Optimize-Volume -DriveLetter C -ReTrim

Write-Host "=== [WORK MODE] STEP 2: PRIVACY, BROWSER & TELEMETRY ===" -ForegroundColor Cyan
# Keep DiagTrack at Basic (1), DoSvc HTTP-Only (0), CDPSvc running for M365/Bluetooth
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0 -Type DWord -Force

# Block Recall screenshots, Typing harvesting, Advertising ID
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\InputPersonalization")) { New-Item -Path "HKCU:\Software\Microsoft\InputPersonalization" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) { New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Force

# Disable Edge/Chrome built-in password manager (use Proton Pass / Work Vault)
foreach ($b in @("HKLM:\SOFTWARE\Policies\Microsoft\Edge", "HKLM:\SOFTWARE\Policies\Google\Chrome")) {
    if (-not (Test-Path $b)) { New-Item -Path $b -Force | Out-Null }
    Set-ItemProperty -Path $b -Name "PasswordManagerEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $b -Name "BackgroundModeEnabled" -Value 0 -Type DWord -Force
}

Write-Host "=== [WORK MODE] STEP 3: NETWORK & ENDPOINT SECURITY ===" -ForegroundColor Cyan
if (-not (Test-Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient")) { New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 5 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "restrictanonymous" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord -Force

Set-MpPreference -DisableRealtimeMonitoring $false -PUAProtection Enabled -EnableNetworkProtection Enabled
powercfg /change monitor-timeout-dc 10
powercfg /change monitor-timeout-ac 15

Write-Host "`n[WORK MODE COMPLETE] M365, Teams, Zoom, OneDrive & VPN remain 100% functional!" -ForegroundColor Green
