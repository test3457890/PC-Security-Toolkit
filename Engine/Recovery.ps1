<#
  Recovery.ps1 - PC Security Toolkit Recovery Engine (v3.0)

  Saves every setting the toolkit is able to change, and puts them back exactly.
  Snapshots live on the USB in:  Backups\<PC name>\<date> <label>.json

  Modes:
    Menu           Interactive recovery menu (used by "RECOVERY MODE Windows.bat")
    Snapshot       Save the current state of this PC
    Restore        Put a snapshot back   (add -DryRun to only preview)
    List           Show the snapshots saved for this PC
    Defaults       Undo all toolkit changes back to Windows defaults (no snapshot needed)
    RemoveFamily   Turn the Family Plan off completely
    RestorePoint   Create a Windows System Restore point
    SystemRestore  Open the Windows System Restore wizard
    Repair         Repair Windows system files (DISM + SFC)
    NetReset       Reset Winsock / TCP-IP / DNS cache
    HostsReset     Put the hosts file back to the Windows default
    NetOff/NetOn   Panic button: cut / restore all network adapters
    WinRE          Restart into the Windows Recovery Environment
    SafeOn/SafeOff Boot into Safe Mode (with networking) on next restart / back to normal
#>
param(
    [ValidateSet('Menu','Snapshot','Restore','List','Defaults','RemoveFamily','RestorePoint','SystemRestore','Repair','NetReset','HostsReset','NetOff','NetOn','WinRE','SafeOn','SafeOff')]
    [string]$Mode = 'Menu',
    [string]$Label = 'Manual snapshot',
    [string]$SnapshotPath = '',
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'
# Use Windows PowerShell's own module folders even if started from a PowerShell 7 window.
if ($PSVersionTable.PSEdition -ne 'Core') {
    $env:PSModulePath = @("$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules", "$env:ProgramFiles\WindowsPowerShell\Modules", "$PSHOME\Modules") -join ';'
}
$EngineDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir        = Split-Path -Parent $EngineDir
$PcName         = $env:COMPUTERNAME
$BackupDir      = Join-Path $RootDir "Backups\$PcName"
$FamilyFile     = Join-Path $RootDir 'Config\family settings.json'
$HostsPath      = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$FamilyStart    = '# >>> PC Security Toolkit Family Plan >>>'
$FamilyEnd      = '# <<< PC Security Toolkit Family Plan <<<'
$TaskPath       = '\PC Security Toolkit\'
$ProgramDataDir = Join-Path $env:ProgramData 'PC Security Toolkit'
$IsAdmin        = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$FamilyDns = @('1.1.1.3','1.0.0.3','2606:4700:4700::1113','2606:4700:4700::1003',
               '185.228.168.168','185.228.169.168','2a0d:2a00:1::','2a0d:2a00:2::',
               '208.67.222.123','208.67.220.123','2620:119:35::123','2620:119:53::123')

$Edge    = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Chrome  = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
$Firefox = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox'
$FamilyBrowserValues = @('ForceGoogleSafeSearch','ForceYouTubeRestrict','ForceBingSafeSearch','InPrivateModeAvailability',
                         'IncognitoModeAvailability','BrowserGuestModeEnabled','AllowDeletingBrowserHistory','DnsOverHttpsMode')

# Every registry location the toolkit can touch.
#   key    = owned by the toolkit: restored exactly (new values are removed)
#   values = shared Windows key: only the listed values are restored
#   readd  = startup lists: anything the toolkit removed is put back, nothing new is deleted
$Tracked = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Mode = 'key' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Mode = 'values'; Values = @('DisableSearchBoxSuggestions') },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Mode = 'values'; Values = @('DODownloadMode') },
    @{ Path = 'HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient'; Mode = 'values'; Values = @('EnableMulticast') },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad'; Mode = 'values'; Values = @('WpadOverride') },
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Mode = 'values'; Values = @('LmCompatibilityLevel','restrictanonymous') },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Mode = 'values'; Values = @('NoDriveTypeAutoRun','NoAutorun') },
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'; Mode = 'values'; Values = @('fAllowToGetHelp') },
    @{ Path = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore'; Mode = 'values'; Values = @('SystemRestorePointCreationFrequency') },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Mode = 'values'; Values = @('01','04') },
    @{ Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Mode = 'values'; Values = @('RestrictImplicitTextCollection','RestrictImplicitInkCollection') },
    @{ Path = 'HKCU:\Software\Microsoft\Input\TIPC'; Mode = 'values'; Values = @('Enabled') },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Mode = 'values'; Values = @('BingSearchEnabled') },
    @{ Path = 'HKCU:\Software\Microsoft\Clipboard'; Mode = 'values'; Values = @('EnableClipboardHistory','EnableCloudClipboard') },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Mode = 'values'; Values = @('Enabled') },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Mode = 'values'; Values = @('Start_TrackProgs','Start_TrackDocs') },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Mode = 'readd' },
    @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Mode = 'readd' },
    @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Mode = 'readd' },
    @{ Path = $Edge; Mode = 'key' },
    @{ Path = "$Edge\URLBlocklist"; Mode = 'key' },
    @{ Path = "$Edge\ExtensionInstallBlocklist"; Mode = 'key' },
    @{ Path = $Chrome; Mode = 'key' },
    @{ Path = "$Chrome\URLBlocklist"; Mode = 'key' },
    @{ Path = "$Chrome\ExtensionInstallBlocklist"; Mode = 'key' },
    @{ Path = $Firefox; Mode = 'key' },
    @{ Path = "$Firefox\DNSOverHTTPS"; Mode = 'key' },
    @{ Path = "$Firefox\WebsiteFilter"; Mode = 'key' },
    @{ Path = "$Firefox\WebsiteFilter\Block"; Mode = 'key' }
)

$TrackedServices = @('TermService','WinRM','LMS','RemoteRegistry','MySQL80','MSSQL$SQLEXPRESS','SQLTELEMETRY','SQLWriter',
                     'MapsBroker','dptftcs','NativePushService','!SASCORE','SASKUTIL','SASDIFSV')

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
function Say($text, $color = 'Gray') { if (-not $Quiet) { Write-Host $text -ForegroundColor $color } }

$script:Changes = 0
function Step([string]$Description, [scriptblock]$Action) {
    $script:Changes++
    if ($DryRun) { Say "  would: $Description" 'Yellow'; return }
    try { & $Action; Say "  done:  $Description" 'Green' }
    catch { Say "  FAILED: $Description ($($_.Exception.Message))" 'Red' }
}

function Assert-Admin {
    if ($IsAdmin) { return }
    $argList = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" -Mode $Mode"
    if ($SnapshotPath) { $argList += " -SnapshotPath `"$SnapshotPath`"" }
    if ($DryRun) { $argList += ' -DryRun' }
    if ($Force)  { $argList += ' -Force' }
    try { Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -ErrorAction Stop }
    catch { Write-Host 'Administrator permission is needed for this. Click Yes on the Windows prompt.' -ForegroundColor Red }
    exit
}

function Get-ValueState([string]$Path, [string]$Name) {
    $key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $key) { return $null }
    if (-not ($key.GetValueNames() -contains $Name)) { return $null }
    $kind = $key.GetValueKind($Name).ToString()
    $val  = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
    if ($kind -eq 'Binary') { $val = [Convert]::ToBase64String([byte[]]$val) }
    return [ordered]@{ Name = $Name; Exists = $true; Kind = $kind; Value = $val }
}

function Get-Fingerprint($state) {
    if ($null -eq $state -or -not $state.Exists) { return '<missing>' }
    return "$($state.Kind)|" + (ConvertTo-Json -InputObject $state.Value -Compress -Depth 4)
}

function Set-RegValue([string]$Path, [string]$Name, [string]$Kind, $Value) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
    switch ($Kind) {
        'DWord'       { $v = [int]$Value }
        'QWord'       { $v = [long]$Value }
        'Binary'      { $v = [Convert]::FromBase64String([string]$Value) }
        'MultiString' { $v = [string[]]@($Value) }
        default       { $v = [string]$Value }
    }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $v -PropertyType $Kind -Force -ErrorAction Stop | Out-Null
}

function Get-AdminMembers {
    $out = @(net localgroup Administrators 2>$null)
    $members = @(); $inList = $false
    foreach ($l in $out) {
        if ($l -match '^-{5,}') { $inList = $true; continue }
        if ($inList) {
            if ($l -match '^The command completed' -or -not $l.Trim()) { continue }
            $members += $l.Trim()
        }
    }
    return $members
}

function Get-LogonHours([string]$User) {
    $lines = @(net user "$User" 2>$null)
    $vals = @(); $collect = $false
    foreach ($l in $lines) {
        if ($l -match '^Logon hours allowed\s+(.*)$') { $collect = $true; $vals += $Matches[1].Trim(); continue }
        if ($collect) {
            if ($l -match '^\s{5,}(\S.*)$') { $vals += $Matches[1].Trim() } else { break }
        }
    }
    return (($vals | Where-Object { $_ }) -join '|')
}

function ConvertTo-TimesArg([string]$Hours) {
    if (-not $Hours -or $Hours -eq 'All') { return 'all' }
    if ($Hours -eq 'None') { return '' }
    $map = @{ Monday='M'; Tuesday='T'; Wednesday='W'; Thursday='Th'; Friday='F'; Saturday='Sa'; Sunday='Su' }
    $parts = @()
    foreach ($h in ($Hours -split '\|')) {
        if ($h -match '^(\w+)\s+(\d{1,2}):00\s*([AP]M)\s*-\s*(\d{1,2}):00\s*([AP]M)$' -and $map.ContainsKey($Matches[1])) {
            $parts += "$($map[$Matches[1]]),$($Matches[2])$($Matches[3])-$($Matches[4])$($Matches[5])"
        } else { return $null }
    }
    return ($parts -join ';')
}

function Get-NameServers([string]$Guid) {
    $v4 = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$Guid" -ErrorAction SilentlyContinue).NameServer
    $v6 = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$Guid" -ErrorAction SilentlyContinue).NameServer
    return [ordered]@{ V4 = [string]$v4; V6 = [string]$v6 }
}

# Fast lookups (the built-in cmdlets take 3-15 seconds each, these take milliseconds)
function Get-ServiceState([string]$Name) {
    $p = Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$Name" -ErrorAction SilentlyContinue
    if (-not $p -or $null -eq $p.Start) { return $null }
    $mode = switch ([int]$p.Start) { 0 { 'Boot' } 1 { 'System' } 2 { 'Auto' } 3 { 'Manual' } 4 { 'Disabled' } default { 'Unknown' } }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return [ordered]@{ StartMode = $mode; Delayed = ([int]$p.DelayedAutostart -eq 1); Running = ($svc -and $svc.Status -eq 'Running') }
}

function Get-ToolkitFirewallRules {
    $k = Get-Item -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules' -ErrorAction SilentlyContinue
    if (-not $k) { return @() }
    $rules = @()
    foreach ($id in $k.GetValueNames()) {
        $data = [string]$k.GetValue($id)
        if ($data -match '\|Name=((Toolkit |Block Public )[^|]*)') { $rules += [ordered]@{ Id = $id; Name = $Matches[1] } }
    }
    return $rules
}

function Get-ToolkitTasks {
    try {
        $svc = New-Object -ComObject Schedule.Service
        $svc.Connect()
        $folder = $svc.GetFolder($TaskPath.TrimEnd('\'))
        return @($folder.GetTasks(1) | ForEach-Object { $_.Name })
    } catch { return @() }
}

function Remove-FamilyHostsBlock {
    $text = [IO.File]::ReadAllText($HostsPath)
    $pattern = '(?s)\r?\n?' + [regex]::Escape($FamilyStart) + '.*?' + [regex]::Escape($FamilyEnd) + '\r?\n?'
    if ($text -notmatch [regex]::Escape($FamilyStart)) { return }
    Step 'Remove Family Plan website blocks from the hosts file' {
        attrib.exe -r $HostsPath 2>$null | Out-Null
        $new = [regex]::Replace([IO.File]::ReadAllText($HostsPath), $pattern, "`r`n").TrimEnd() + "`r`n"
        [IO.File]::WriteAllText($HostsPath, $new, [Text.Encoding]::ASCII)
        ipconfig.exe /flushdns | Out-Null
    }
}

# ------------------------------------------------------------------------------
# Snapshot
# ------------------------------------------------------------------------------
function New-Snapshot([string]$SnapLabel) {
    $reg = @()
    foreach ($t in $Tracked) {
        $entry = [ordered]@{ Path = $t.Path; Mode = $t.Mode; Exists = $false; Data = @() }
        $key = Get-Item -LiteralPath $t.Path -ErrorAction SilentlyContinue
        if ($key) {
            $entry.Exists = $true
            $names = if ($t.Mode -eq 'values') { $t.Values } else { @($key.GetValueNames() | Where-Object { $_ }) }
            foreach ($n in $names) {
                $s = Get-ValueState $t.Path $n
                if ($s) { $entry.Data += $s } else { $entry.Data += [ordered]@{ Name = $n; Exists = $false } }
            }
        } elseif ($t.Mode -eq 'values') {
            foreach ($n in $t.Values) { $entry.Data += [ordered]@{ Name = $n; Exists = $false } }
        }
        $reg += $entry
    }

    $services = @()
    foreach ($name in $TrackedServices) {
        $st = Get-ServiceState $name
        if ($st) { $services += [ordered]@{ Name = $name; Exists = $true; StartMode = $st.StartMode; Delayed = $st.Delayed; Running = $st.Running } }
        else     { $services += [ordered]@{ Name = $name; Exists = $false } }
    }

    $netbios = @(); $dns = @()
    foreach ($a in @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE")) {
        $netbios += [ordered]@{ Id = $a.SettingID; Name = $a.Description; Value = $a.TcpipNetbiosOptions }
        $ns = Get-NameServers $a.SettingID
        $dns += [ordered]@{ Id = $a.SettingID; Index = $a.InterfaceIndex; Name = $a.Description; V4 = $ns.V4; V6 = $ns.V6 }
    }

    $fw = @(Get-ToolkitFirewallRules | ForEach-Object { $_.Id })

    $defender = $null
    $mp = Get-MpPreference -ErrorAction SilentlyContinue
    if ($mp -and $null -ne $mp.DisableRealtimeMonitoring) {
        $defender = [ordered]@{
            DisableRealtimeMonitoring = [bool]$mp.DisableRealtimeMonitoring
            PUAProtection             = [int]$mp.PUAProtection
            EnableNetworkProtection   = [int]$mp.EnableNetworkProtection
            CloudBlockLevel           = [int]$mp.CloudBlockLevel
            AsrIds                    = @($mp.AttackSurfaceReductionRules_Ids | Where-Object { $_ })
            AsrActions                = @($mp.AttackSurfaceReductionRules_Actions | ForEach-Object { [int]$_ })
        }
    }

    $hours = @()
    foreach ($u in @(Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { $_.Enabled })) {
        $hours += [ordered]@{ User = $u.Name; Hours = (Get-LogonHours $u.Name) }
    }

    $tasks = @(Get-ToolkitTasks)

    $snap = [ordered]@{
        Format      = 'PC Security Toolkit snapshot'
        Version     = 3
        Label       = $SnapLabel
        Created     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
        Computer    = $PcName
        User        = $env:USERNAME
        Elevated    = $IsAdmin
        Registry    = $reg
        Services    = $services
        NetBios     = $netbios
        Dns         = $dns
        Firewall    = $fw
        Defender    = $defender
        LogonHours  = $hours
        Admins      = @(Get-AdminMembers)
        Tasks       = $tasks
        HostsBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($HostsPath))
    }

    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $safe = ($SnapLabel -replace '[^A-Za-z0-9 \-\.\(\)]', ' ' -replace '\s+', ' ').Trim()
    if ($safe.Length -gt 60) { $safe = $safe.Substring(0, 60).Trim() }
    if (-not $safe) { $safe = 'Snapshot' }
    $file = Join-Path $BackupDir ("{0} {1}.json" -f (Get-Date -Format 'yyyy-MM-dd HH-mm-ss'), $safe)
    $snap | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $file -Encoding UTF8
    return $file
}

# ------------------------------------------------------------------------------
# Restore
# ------------------------------------------------------------------------------
function Restore-Snapshot([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { Say "Snapshot not found: $Path" 'Red'; return }
    $snap = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($snap.Format -ne 'PC Security Toolkit snapshot') { Say 'That file is not a toolkit snapshot.' 'Red'; return }
    if ($snap.Computer -ne $PcName -and -not $Force) {
        Say "This snapshot was made on '$($snap.Computer)', not on this PC ('$PcName'). Refusing to restore it here." 'Red'
        return
    }

    Say ''
    Say "Snapshot: $($snap.Label)   (taken $($snap.Created))" 'Cyan'
    if ($DryRun) { Say 'PREVIEW ONLY - nothing will be changed.' 'Yellow' }
    else {
        $before = New-Snapshot "Before restoring $($snap.Label)"
        Say "Safety net: the current state was saved first ($([IO.Path]::GetFileName($before)))" 'DarkGray'
    }

    Say ''; Say '[Registry settings]' 'Cyan'
    foreach ($r in $snap.Registry) {
        $p = $r.Path
        $exists = Test-Path -LiteralPath $p
        if ($r.Mode -eq 'key') {
            if (-not $r.Exists) {
                if ($exists) { Step "Remove $p" { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } }
                continue
            }
            $want = @{}
            foreach ($d in @($r.Data)) { if ($d.Name) { $want[$d.Name] = $d } }
            if ($exists) {
                foreach ($n in @((Get-Item -LiteralPath $p).GetValueNames() | Where-Object { $_ })) {
                    if (-not $want.ContainsKey($n)) { Step "Remove $p\$n" { Remove-ItemProperty -LiteralPath $p -Name $n -Force -ErrorAction Stop } }
                }
            } elseif (@($r.Data).Count -eq 0) {
                Step "Re-create empty key $p" { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
            }
        }
        foreach ($d in @($r.Data)) {
            if (-not $d.Name) { continue }
            $cur = Get-ValueState $p $d.Name
            if ($d.Exists) {
                if ((Get-Fingerprint $cur) -ne (Get-Fingerprint $d)) {
                    Step "Set $p\$($d.Name) = $($d.Value)" { Set-RegValue $p $d.Name $d.Kind $d.Value }
                }
            } elseif ($cur -and $r.Mode -ne 'readd') {
                Step "Remove $p\$($d.Name)" { Remove-ItemProperty -LiteralPath $p -Name $d.Name -Force -ErrorAction Stop }
            }
        }
    }

    Say ''; Say '[Windows services]' 'Cyan'
    foreach ($s in @($snap.Services)) {
        if (-not $s.Exists) { continue }
        $svc = Get-ServiceState $s.Name
        if (-not $svc) { continue }
        if ($svc.StartMode -ne $s.StartMode -or [bool]$svc.Delayed -ne [bool]$s.Delayed) {
            $start = switch ($s.StartMode) { 'Auto' { if ($s.Delayed) { 'delayed-auto' } else { 'auto' } } 'Manual' { 'demand' } 'Disabled' { 'disabled' } default { $null } }
            if ($start) { Step "Service $($s.Name) start type -> $($s.StartMode)" { sc.exe config "$($s.Name)" start= $start | Out-Null } }
        }
        if ($s.Running -and -not $svc.Running) { Step "Start service $($s.Name)" { Start-Service -Name $s.Name -ErrorAction Stop } }
    }

    Say ''; Say '[Network: NetBIOS and DNS]' 'Cyan'
    foreach ($n in @($snap.NetBios)) {
        $a = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "SettingID='$($n.Id)'" -ErrorAction SilentlyContinue
        if ($a -and $a.TcpipNetbiosOptions -ne $n.Value -and $null -ne $n.Value) {
            Step "NetBIOS on '$($n.Name)' -> $($n.Value)" { Invoke-CimMethod -InputObject $a -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]$n.Value } | Out-Null }
        }
    }
    foreach ($d in @($snap.Dns)) {
        $cur = Get-NameServers $d.Id
        if ($cur.V4 -ne $d.V4 -or $cur.V6 -ne $d.V6) {
            $idx = (Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "SettingID='$($d.Id)'" -ErrorAction SilentlyContinue).InterfaceIndex
            if (-not $idx) { continue }
            $servers = @(("$($d.V4) $($d.V6)" -split '[,\s]+') | Where-Object { $_ })
            if ($servers.Count -eq 0) { Step "DNS on '$($d.Name)' -> automatic" { Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction Stop } }
            else { Step "DNS on '$($d.Name)' -> $($servers -join ', ')" { Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $servers -ErrorAction Stop } }
        }
    }

    Say ''; Say '[Hosts file]' 'Cyan'
    if ($snap.HostsBase64) {
        $want = [Convert]::FromBase64String($snap.HostsBase64)
        $now  = [IO.File]::ReadAllBytes($HostsPath)
        if ([Convert]::ToBase64String($now) -ne $snap.HostsBase64) {
            Step 'Put the hosts file back' {
                attrib.exe -r $HostsPath 2>$null | Out-Null
                [IO.File]::WriteAllBytes($HostsPath, $want)
                ipconfig.exe /flushdns | Out-Null
            }
        }
    }

    Say ''; Say '[Firewall rules made by the toolkit]' 'Cyan'
    $keep = @($snap.Firewall)
    foreach ($rule in @(Get-ToolkitFirewallRules)) {
        if ($keep -notcontains $rule.Id) { $rid = $rule.Id; Step "Remove firewall rule '$($rule.Name)'" { Remove-NetFirewallRule -Name $rid -ErrorAction Stop } }
    }

    Say ''; Say '[Windows Defender]' 'Cyan'
    if ($snap.Defender) {
        $mp = Get-MpPreference -ErrorAction SilentlyContinue
        $d = $snap.Defender
        if ($mp) {
            if ([bool]$mp.DisableRealtimeMonitoring -ne [bool]$d.DisableRealtimeMonitoring) {
                if ($d.DisableRealtimeMonitoring) { Say '  note: this snapshot had Real-Time Protection OFF. Leaving it ON for your safety.' 'Yellow' }
                else { Step 'Defender Real-Time Protection -> ON' { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop } }
            }
            if ([int]$mp.PUAProtection -ne [int]$d.PUAProtection) { Step "Defender PUA protection -> $($d.PUAProtection)" { Set-MpPreference -PUAProtection ([int]$d.PUAProtection) -ErrorAction Stop } }
            if ([int]$mp.EnableNetworkProtection -ne [int]$d.EnableNetworkProtection) { Step "Defender Network Protection -> $($d.EnableNetworkProtection)" { Set-MpPreference -EnableNetworkProtection ([int]$d.EnableNetworkProtection) -ErrorAction Stop } }
            if ([int]$mp.CloudBlockLevel -ne [int]$d.CloudBlockLevel) { Step "Defender cloud block level -> $($d.CloudBlockLevel)" { Set-MpPreference -CloudBlockLevel ([int]$d.CloudBlockLevel) -ErrorAction Stop } }
            $oldIds = @($d.AsrIds); $oldAct = @($d.AsrActions)
            $curIds = @($mp.AttackSurfaceReductionRules_Ids | Where-Object { $_ }); $curAct = @($mp.AttackSurfaceReductionRules_Actions)
            for ($i = 0; $i -lt $curIds.Count; $i++) {
                if ($oldIds -notcontains $curIds[$i]) { $id = $curIds[$i]; Step "Remove Defender ASR rule $id" { Remove-MpPreference -AttackSurfaceReductionRules_Ids $id -ErrorAction Stop } }
            }
            for ($i = 0; $i -lt $oldIds.Count; $i++) {
                $id = $oldIds[$i]; $act = [int]$oldAct[$i]; $j = [array]::IndexOf($curIds, $id)
                if ($j -lt 0 -or [int]$curAct[$j] -ne $act) { Step "Defender ASR rule $id -> $act" { Add-MpPreference -AttackSurfaceReductionRules_Ids $id -AttackSurfaceReductionRules_Actions $act -ErrorAction Stop } }
            }
        }
    } else { Say '  (this snapshot has no Defender data - it was taken without admin rights)' 'DarkGray' }

    Say ''; Say '[Accounts: sign-in hours, admin rights, scheduled tasks]' 'Cyan'
    foreach ($h in @($snap.LogonHours)) {
        if (-not (Get-LocalUser -Name $h.User -ErrorAction SilentlyContinue)) { continue }
        $now = Get-LogonHours $h.User
        if ($now -ne $h.Hours) {
            $arg = ConvertTo-TimesArg $h.Hours
            if ($null -eq $arg) { Say "  skip: could not read the old sign-in hours for $($h.User) ($($h.Hours))" 'Yellow'; continue }
            Step "Sign-in hours for $($h.User) -> $(if ($h.Hours) { $h.Hours } else { 'All' })" { net user "$($h.User)" "/times:$arg" | Out-Null }
        }
    }
    $nowAdmins = @(Get-AdminMembers)
    foreach ($m in @($snap.Admins)) {
        if ($nowAdmins -notcontains $m) { Step "Give admin rights back to $m" { net localgroup Administrators "$m" /add | Out-Null } }
    }
    $keepTasks = @($snap.Tasks)
    foreach ($tn in @(Get-ToolkitTasks)) {
        if ($keepTasks -notcontains $tn) { $name = $tn; Step "Remove scheduled task '$tn'" { Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $name -Confirm:$false -ErrorAction Stop } }
    }

    Say ''
    if ($script:Changes -eq 0) { Say 'Nothing to change - this PC already matches the snapshot.' 'Green' }
    elseif ($DryRun) { Say "$($script:Changes) change(s) would be made." 'Yellow' }
    else { Say "Finished: $($script:Changes) change(s). Restart your browser, and restart the PC if networking changed." 'Green' }
}

# ------------------------------------------------------------------------------
# Family Plan removal + full "back to Windows defaults"
# ------------------------------------------------------------------------------
function Remove-FamilyPlan {
    Say ''; Say '[Turning the Family Plan off]' 'Cyan'
    Remove-FamilyHostsBlock
    foreach ($b in @($Edge, $Chrome)) {
        foreach ($v in $FamilyBrowserValues) {
            if (Get-ValueState $b $v) { Step "Remove browser rule $v" { Remove-ItemProperty -LiteralPath $b -Name $v -Force -ErrorAction Stop } }
        }
        if (Test-Path -LiteralPath "$b\URLBlocklist") { Step "Remove blocked sites list ($b)" { Remove-Item -LiteralPath "$b\URLBlocklist" -Recurse -Force -ErrorAction Stop } }
    }
    foreach ($k in @("$Firefox\WebsiteFilter", "$Firefox\DNSOverHTTPS")) {
        if (Test-Path -LiteralPath $k) { Step "Remove Firefox rule $k" { Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction Stop } }
    }
    foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue)) {
        $cur = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ErrorAction SilentlyContinue).ServerAddresses)
        if ($cur | Where-Object { $FamilyDns -contains $_ }) {
            $idx = $a.ifIndex
            Step "DNS on '$($a.Name)' -> automatic" { Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction Stop }
        }
    }
    $kids = @()
    if (Test-Path -LiteralPath $FamilyFile) {
        $cfg = Get-Content -LiteralPath $FamilyFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $kids += @($cfg.kids | ForEach-Object { $_.name })
    }
    foreach ($tn in @(Get-ToolkitTasks | Where-Object { $_ -like 'Family*' })) {
        if ($tn -match '^Family Bedtime (.+)$') { $kids += $Matches[1] }
        $name = $tn
        Step "Remove bedtime task '$tn'" { Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $name -Confirm:$false -ErrorAction Stop }
    }
    foreach ($k in ($kids | Where-Object { $_ } | Select-Object -Unique)) {
        if ((Get-LogonHours $k) -and (Get-LogonHours $k) -ne 'All') { Step "Sign-in hours for $k -> any time" { net user "$k" /times:all | Out-Null } }
    }
    if (Test-Path -LiteralPath (Join-Path $ProgramDataDir 'Bedtime.ps1')) {
        Step 'Remove bedtime helper script' { Remove-Item -LiteralPath (Join-Path $ProgramDataDir 'Bedtime.ps1') -Force -ErrorAction Stop }
    }
    Say '  note: kids that were changed to Standard accounts stay Standard. Use a snapshot restore to give admin rights back.' 'DarkGray'
}

function Set-WindowsDefaults {
    Say ''; Say '[Putting every toolkit setting back to Windows defaults]' 'Cyan'
    $removeValues = @(
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer','DisableSearchBoxSuggestions'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization','DODownloadMode'),
        @('HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient','EnableMulticast'),
        @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad','WpadOverride'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','LmCompatibilityLevel'),
        @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer','NoDriveTypeAutoRun'),
        @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer','NoAutorun'),
        @('HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore','SystemRestorePointCreationFrequency'),
        @('HKCU:\Software\Microsoft\InputPersonalization','RestrictImplicitTextCollection'),
        @('HKCU:\Software\Microsoft\InputPersonalization','RestrictImplicitInkCollection'),
        @('HKCU:\Software\Microsoft\Input\TIPC','Enabled'),
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search','BingSearchEnabled'),
        @('HKCU:\Software\Microsoft\Clipboard','EnableClipboardHistory'),
        @('HKCU:\Software\Microsoft\Clipboard','EnableCloudClipboard')
    )
    foreach ($b in @($Edge, $Chrome)) { foreach ($v in @('PasswordManagerEnabled','BackgroundModeEnabled','StartupBoostEnabled')) { $removeValues += ,@($b, $v) } }
    foreach ($rv in $removeValues) {
        if (Get-ValueState $rv[0] $rv[1]) { $p = $rv[0]; $n = $rv[1]; Step "Remove $p\$n" { Remove-ItemProperty -LiteralPath $p -Name $n -Force -ErrorAction Stop } }
    }
    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI') { Step 'Remove Recall policy (WindowsAI)' { Remove-Item -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Recurse -Force -ErrorAction Stop } }
    $setValues = @(
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance','fAllowToGetHelp',1),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa','restrictanonymous',0),
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo','Enabled',1)
    )
    foreach ($sv in $setValues) {
        $cur = Get-ValueState $sv[0] $sv[1]
        if (-not $cur -or [int]$cur.Value -ne $sv[2]) { $p = $sv[0]; $n = $sv[1]; $v = $sv[2]; Step "Set $p\$n = $v" { Set-RegValue $p $n 'DWord' $v } }
    }
    $svcDefaults = @{ TermService = 'demand'; WinRM = 'demand'; MapsBroker = 'delayed-auto'; LMS = 'auto' }
    foreach ($name in $svcDefaults.Keys) {
        if (Get-Service -Name $name -ErrorAction SilentlyContinue) { $sd = $svcDefaults[$name]; Step "Service $name start type -> Windows default" { sc.exe config $name start= $sd | Out-Null } }
    }
    foreach ($a in @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' | Where-Object { $_.TcpipNetbiosOptions -eq 2 })) {
        $ad = $a; Step "NetBIOS on '$($a.Description)' -> default" { Invoke-CimMethod -InputObject $ad -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]0 } | Out-Null }
    }
    foreach ($rule in @(Get-ToolkitFirewallRules)) {
        $rn = $rule.Id; Step "Remove firewall rule '$($rule.Name)'" { Remove-NetFirewallRule -Name $rn -ErrorAction Stop }
    }
    Remove-FamilyPlan
    Say ''
    Say '  kept on purpose: Defender protection, blocked bad browser extensions, and the safer Remote Registry setting.' 'DarkGray'
    Say "Finished: $($script:Changes) change(s). Restart the PC to finish." 'Green'
}

# ------------------------------------------------------------------------------
# Repair tools
# ------------------------------------------------------------------------------
$DefaultHosts = @'
# Copyright (c) 1993-2009 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
# This file contains the mappings of IP addresses to host names. Each
# entry should be kept on an individual line. The IP address should
# be placed in the first column followed by the corresponding host name.
# The IP address and the host name should be separated by at least one
# space.
#
# Additionally, comments (such as these) may be inserted on individual
# lines or following the machine name denoted by a '#' symbol.
#
# For example:
#
#      102.54.94.97     rhino.acme.com          # source server
#       38.25.63.10     x.acme.com              # x client host

# localhost name resolution is handled within DNS itself.
#	127.0.0.1       localhost
#	::1             localhost
'@

function Invoke-Tool([string]$Which) {
    switch ($Which) {
        'RestorePoint' {
            Say 'Creating a Windows System Restore point...' 'Cyan'
            Enable-ComputerRestore -Drive "$env:SystemDrive\"
            New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null
            try { Checkpoint-Computer -Description 'PC Security Toolkit restore point' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; Say 'Restore point created.' 'Green' }
            catch { Say "Could not create a restore point: $($_.Exception.Message)" 'Red' }
        }
        'SystemRestore' { Start-Process rstrui.exe; Say 'Opened Windows System Restore.' 'Green' }
        'Repair' {
            Say 'Step 1 of 2: DISM is repairing the Windows component store (can take 10-20 minutes)...' 'Cyan'
            DISM.exe /Online /Cleanup-Image /RestoreHealth
            Say 'Step 2 of 2: System File Checker is repairing Windows files...' 'Cyan'
            sfc.exe /scannow
            Say 'Repair finished. Restart the PC when you can.' 'Green'
        }
        'NetReset' {
            Say 'Resetting Winsock, TCP/IP and the DNS cache...' 'Cyan'
            netsh.exe winsock reset
            netsh.exe int ip reset
            ipconfig.exe /flushdns
            Say 'Network reset finished. Restart the PC to finish.' 'Green'
        }
        'HostsReset' {
            $copy = Join-Path $BackupDir ("hosts backup {0}.txt" -f (Get-Date -Format 'yyyy-MM-dd HH-mm-ss'))
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Copy-Item -LiteralPath $HostsPath -Destination $copy -Force
            attrib.exe -r $HostsPath 2>$null | Out-Null
            [IO.File]::WriteAllText($HostsPath, $DefaultHosts + "`r`n", [Text.Encoding]::ASCII)
            ipconfig.exe /flushdns | Out-Null
            Say "Hosts file is back to the Windows default. Old copy saved to: $copy" 'Green'
        }
        'NetOff' {
            Get-NetAdapter -Physical | Disable-NetAdapter -Confirm:$false
            Say 'All network adapters are OFF. Run "Restore internet" (NetOn) to turn them back on.' 'Yellow'
        }
        'NetOn' {
            Get-NetAdapter -Physical | Enable-NetAdapter -Confirm:$false
            Say 'Network adapters are back ON.' 'Green'
        }
        'WinRE' {
            Say 'Restarting into the Windows Recovery Environment in 10 seconds...' 'Yellow'
            shutdown.exe /r /o /t 10
        }
        'SafeOn' {
            bcdedit.exe /set '{current}' safeboot network | Out-Null
            Say 'Next restart will boot into Safe Mode with Networking.' 'Yellow'
            Say 'To go back to normal: double-click "RECOVERY MODE Windows.bat" on the USB and pick "Leave Safe Mode".' 'Yellow'
        }
        'SafeOff' {
            bcdedit.exe /deletevalue '{current}' safeboot | Out-Null
            Say 'Safe Mode is turned off. The next restart will be a normal start.' 'Green'
        }
    }
}

function Get-SnapshotList {
    if (-not (Test-Path -LiteralPath $BackupDir)) { return @() }
    return @(Get-ChildItem -LiteralPath $BackupDir -Filter '*.json' | Sort-Object Name -Descending)
}

# ------------------------------------------------------------------------------
# Menu (RECOVERY MODE Windows.bat)
# ------------------------------------------------------------------------------
function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host '=================================================================' -ForegroundColor Cyan
        Write-Host '   PC SECURITY TOOLKIT - RECOVERY MODE' -ForegroundColor Green
        Write-Host "   PC: $PcName      Snapshots on this USB: $((Get-SnapshotList).Count)" -ForegroundColor Gray
        Write-Host '=================================================================' -ForegroundColor Cyan
        Write-Host '   1  Undo toolkit changes (pick a snapshot)'
        Write-Host '   2  Undo EVERYTHING the toolkit did (back to Windows defaults)'
        Write-Host '   3  Turn the Family Plan off'
        Write-Host '   4  Take a snapshot now'
        Write-Host '   5  Create a Windows System Restore point'
        Write-Host '   6  Open Windows System Restore (roll the whole PC back)'
        Write-Host '   7  Repair Windows system files (DISM + SFC)'
        Write-Host '   8  Fix the internet (reset network)'
        Write-Host '   9  Reset the hosts file'
        Write-Host '  10  PANIC: cut the internet       11  Restore the internet'
        Write-Host '  12  Restart into Windows Recovery (advanced startup)'
        Write-Host '  13  Safe Mode on next restart     14  Leave Safe Mode'
        Write-Host '   0  Exit'
        Write-Host ''
        $c = Read-Host 'Pick a number'
        switch ($c) {
            '1' {
                $list = Get-SnapshotList
                if ($list.Count -eq 0) { Write-Host 'No snapshots for this PC yet.' -ForegroundColor Yellow; break }
                for ($i = 0; $i -lt [Math]::Min($list.Count, 20); $i++) { Write-Host ("  {0,2}  {1}" -f ($i + 1), $list[$i].BaseName) }
                $pick = Read-Host 'Which snapshot (number)'
                $n = 0
                if ([int]::TryParse($pick, [ref]$n) -and $n -ge 1 -and $n -le $list.Count) {
                    $file = $list[$n - 1].FullName
                    $script:DryRun = $true; $script:Changes = 0; Restore-Snapshot $file
                    $script:DryRun = $false
                    if ($script:Changes -gt 0 -and (Read-Host 'Apply these changes? (Y/N)') -match '^[Yy]') { $script:Changes = 0; Restore-Snapshot $file }
                }
            }
            '2'  { if ((Read-Host 'Undo every toolkit change on this PC? (Y/N)') -match '^[Yy]') { New-Snapshot 'Before Windows defaults' | Out-Null; $script:Changes = 0; Set-WindowsDefaults } }
            '3'  { New-Snapshot 'Before removing Family Plan' | Out-Null; $script:Changes = 0; Remove-FamilyPlan; Say 'Family Plan is off.' 'Green' }
            '4'  { $l = Read-Host 'Name for this snapshot'; if (-not $l) { $l = 'Manual snapshot' }; Write-Host "Saved: $(New-Snapshot $l)" -ForegroundColor Green }
            '5'  { Invoke-Tool 'RestorePoint' }
            '6'  { Invoke-Tool 'SystemRestore' }
            '7'  { Invoke-Tool 'Repair' }
            '8'  { Invoke-Tool 'NetReset' }
            '9'  { if ((Read-Host 'Reset the hosts file to the Windows default? (Y/N)') -match '^[Yy]') { Invoke-Tool 'HostsReset' } }
            '10' { if ((Read-Host 'Turn OFF all network adapters? (Y/N)') -match '^[Yy]') { Invoke-Tool 'NetOff' } }
            '11' { Invoke-Tool 'NetOn' }
            '12' { if ((Read-Host 'Restart into Windows Recovery now? Save your work first. (Y/N)') -match '^[Yy]') { Invoke-Tool 'WinRE' } }
            '13' { if ((Read-Host 'Boot into Safe Mode on next restart? (Y/N)') -match '^[Yy]') { Invoke-Tool 'SafeOn' } }
            '14' { Invoke-Tool 'SafeOff' }
            '0'  { return }
        }
        Write-Host ''
        Read-Host 'Press Enter to go back to the menu' | Out-Null
    }
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------
function Start-RecoveryLog {
    $dir = Join-Path $RootDir "Logs\$PcName"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $file = Join-Path $dir ("recovery {0} {1}.log" -f (Get-Date -Format 'yyyy-MM-dd HH-mm-ss'), $Mode)
    try { Start-Transcript -LiteralPath $file -Append | Out-Null; Write-Host "(Everything here is also saved to Logs\$PcName\$([IO.Path]::GetFileName($file)))" -ForegroundColor DarkGray } catch {}
}

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host 'Windows is running this in restricted mode (the files came from an internet ZIP).' -ForegroundColor Yellow
    Write-Host 'Fix: right-click the downloaded ZIP > Properties > tick Unblock, then extract it again.' -ForegroundColor Yellow
    Read-Host 'Press Enter to close' | Out-Null
    exit
}

switch ($Mode) {
    'Snapshot' { $f = New-Snapshot $Label; if ($Quiet) { $f } else { Say "Snapshot saved: $f" 'Green' } }
    'List' {
        foreach ($s in Get-SnapshotList) { $s.BaseName }
    }
    'Restore' {
        if (-not $DryRun) { Assert-Admin; Start-RecoveryLog }
        Restore-Snapshot $SnapshotPath
    }
    'Defaults'     { Assert-Admin; Start-RecoveryLog; New-Snapshot 'Before Windows defaults' | Out-Null; Set-WindowsDefaults }
    'RemoveFamily' { Assert-Admin; Start-RecoveryLog; New-Snapshot 'Before removing Family Plan' | Out-Null; Remove-FamilyPlan; Say ''; Say 'Family Plan is off. Restart browsers to finish.' 'Green' }
    'Menu'         { Assert-Admin; Start-RecoveryLog; Show-Menu }
    default        { Assert-Admin; Start-RecoveryLog; Invoke-Tool $Mode }
}
