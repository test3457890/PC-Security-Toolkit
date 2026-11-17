# ==============================================================================
# 2 School Laptop.ps1 — SCHOOLWORK, CODING & CAMPUS WI-FI MODE
# Best for: Classrooms, libraries, Python/Node/WSL/SQL dev, and campus Wi-Fi.
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Save a recovery snapshot first so every change can be undone in Recovery Mode
$toolkitRecovery = Join-Path (Split-Path -Parent $PSScriptRoot) "Engine\Recovery.ps1"
if (Test-Path -LiteralPath $toolkitRecovery) { & $toolkitRecovery -Mode Snapshot -Label "Before profile $([IO.Path]::GetFileNameWithoutExtension($PSCommandPath))" -Quiet | Out-Null }

Write-Host "=== [SCHOOL MODE] STEP 1: RESTORE POINT & SAFE CACHE CLEANUP ===" -ForegroundColor Cyan
Enable-ComputerRestore -Drive "C:\"
Checkpoint-Computer -Description "Pre-School-Optimization" -RestorePointType "MODIFY_SETTINGS"
foreach ($c in @("$env:LOCALAPPDATA\npm-cache", "$env:USERPROFILE\.cache", "$env:USERPROFILE\.nuget\packages", "$env:LOCALAPPDATA\Temp")) {
    if (Test-Path $c) { Remove-Item "$c\*" -Recurse -Force }
}
Optimize-Volume -DriveLetter C -ReTrim

Write-Host "=== [SCHOOL MODE] STEP 2: CAMPUS WI-FI & USB PROTECTION ===" -ForegroundColor Cyan
if (-not (Test-Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient")) { New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" | Where-Object { $_.Description -match 'Wi-Fi|Wireless|WLAN' } | ForEach-Object {
    Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions = [uint32]2} | Out-Null
}
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutorun" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 5 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "restrictanonymous" -Value 1 -Type DWord -Force

# Set heavy local DB services to Manual (start on demand for class projects)
foreach ($svc in @("MySQL80", "MSSQL`$SQLEXPRESS", "SQLTELEMETRY", "SQLTELEMETRY`$SQLEXPRESS", "SQLWriter", "MapsBroker", "dptftcs")) {
    if (Get-Service -Name $svc) {
        Set-Service -Name $svc -StartupType Manual
        Stop-Service -Name $svc -Force
    }
}

# 10 min battery / 15 min AC screen lock
powercfg /change monitor-timeout-dc 10
powercfg /change monitor-timeout-ac 15
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 1
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 1
powercfg /SETACTIVE SCHEME_CURRENT

Write-Host "=== [SCHOOL MODE] STEP 3: PRIVACY & DEFENDER AUDIT MODE ===" -ForegroundColor Cyan
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKCU:\Software\Microsoft\InputPersonalization")) { New-Item -Path "HKCU:\Software\Microsoft\InputPersonalization" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord -Force
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0 -Type DWord -Force

Set-MpPreference -DisableRealtimeMonitoring $false -PUAProtection Enabled -EnableNetworkProtection Enabled -CloudBlockLevel Default
Write-Host "`n[SCHOOL MODE COMPLETE] Dev tools (Python, Node, WSL, VMs) & recent docs remain 100% usable!" -ForegroundColor Green
