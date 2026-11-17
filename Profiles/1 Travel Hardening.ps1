# ==============================================================================
# 1 Travel Hardening.ps1 — MAXIMUM TRAVEL & PUBLIC WI-FI SECURITY
# Best for: Airports, hotels, coffee shops, conferences, and untrusted Wi-Fi.
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Save a recovery snapshot first so every change can be undone in Recovery Mode
$toolkitRecovery = Join-Path (Split-Path -Parent $PSScriptRoot) "Engine\Recovery.ps1"
if (Test-Path -LiteralPath $toolkitRecovery) { & $toolkitRecovery -Mode Snapshot -Label "Before profile $([IO.Path]::GetFileNameWithoutExtension($PSCommandPath))" -Quiet | Out-Null }

Write-Host "=== [TRAVEL MODE] STEP 1: SYSTEM RESTORE POINT ===" -ForegroundColor Cyan
Enable-ComputerRestore -Drive "C:\"
New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force | Out-Null
Checkpoint-Computer -Description "Pre-Travel-Hardening" -RestorePointType "MODIFY_SETTINGS"

Write-Host "=== [TRAVEL MODE] STEP 2: STORAGE & SSD TRIM ===" -ForegroundColor Cyan
foreach ($c in @("$env:LOCALAPPDATA\npm-cache", "$env:USERPROFILE\.cache", "$env:USERPROFILE\.nuget\packages", "$env:LOCALAPPDATA\Temp")) {
    if (Test-Path $c) { Remove-Item "$c\*" -Recurse -Force }
}
Optimize-Volume -DriveLetter C -ReTrim

Write-Host "=== [TRAVEL MODE] STEP 3: NETWORK & PUBLIC WI-FI LOCKDOWN ===" -ForegroundColor Cyan
# Disable LLMNR, NetBIOS on Wi-Fi, WPAD, Remote Assistance, USB AutoRun
if (-not (Test-Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient")) { New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force

Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" | Where-Object { $_.Description -match 'Wi-Fi|Wireless|WLAN' } | ForEach-Object {
    Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions = [uint32]2} | Out-Null
}

if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutorun" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers")) { New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Value 1 -Type DWord -Force

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1 -Type DWord -Force
Set-Service -Name "TermService", "WinRM", "LMS", "RemoteRegistry" -StartupType Disabled
Stop-Service -Name "TermService", "WinRM", "LMS", "RemoteRegistry" -Force

if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "AutoDetect" -Value 0 -Type DWord -Force

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 5 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "restrictanonymous" -Value 1 -Type DWord -Force

# Block common lateral/DB/discovery ports on Public Wi-Fi
New-NetFirewallRule -DisplayName "Travel Block Public 3306"  -Direction Inbound -Protocol TCP -LocalPort 3306  -Action Block -Profile Public -Enabled True | Out-Null
New-NetFirewallRule -DisplayName "Travel Block Public 33060" -Direction Inbound -Protocol TCP -LocalPort 33060 -Action Block -Profile Public -Enabled True | Out-Null
New-NetFirewallRule -DisplayName "Travel Block Public 5040"  -Direction Inbound -Protocol TCP -LocalPort 5040  -Action Block -Profile Public -Enabled True | Out-Null

# Short travel screen lock (5 min battery, 10 min AC) + PIN on wake
powercfg /change monitor-timeout-dc 5
powercfg /change monitor-timeout-ac 10
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 1
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 1
powercfg /SETACTIVE SCHEME_CURRENT

Write-Host "=== [TRAVEL MODE] STEP 4: PRIVACY, ANTI-LOGGING & DEFENDER ===" -ForegroundColor Cyan
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0 -Type DWord -Force

if (-not (Test-Path "HKCU:\Software\Microsoft\InputPersonalization")) { New-Item -Path "HKCU:\Software\Microsoft\InputPersonalization" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord -Force

if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\Clipboard")) { New-Item -Path "HKCU:\Software\Microsoft\Clipboard" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableCloudClipboard" -Value 0 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) { New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Force

Set-MpPreference -DisableRealtimeMonitoring $false -PUAProtection Enabled -EnableNetworkProtection Enabled
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0 -Type DWord -Force

Write-Host "`n[TRAVEL MODE COMPLETE] Check BitLocker status below:" -ForegroundColor Green
manage-bde.exe -status C:
