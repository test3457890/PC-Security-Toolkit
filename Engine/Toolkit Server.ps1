# ==============================================================================
# Toolkit Server.ps1 (v3.0) - Portable USB localhost server for Windows
# Binds ONLY to http://127.0.0.1:8765/ (nothing on your network can reach it).
# Every API call needs the secret token that is written into the page at start-up,
# so other websites open in your browser cannot drive the toolkit.
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"
# Use Windows PowerShell's own module folders even if started from a PowerShell 7 window.
if ($PSVersionTable.PSEdition -ne 'Core') {
    $env:PSModulePath = @("$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules", "$env:ProgramFiles\WindowsPowerShell\Modules", "$PSHOME\Modules") -join ';'
}

# Files downloaded as a ZIP from the internet can make Windows run scripts in a restricted
# "Constrained Language" mode, where the toolkit cannot start. Explain how to fix it.
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host ''
    Write-Host '  Windows is running the toolkit in restricted mode, so it cannot start.' -ForegroundColor Yellow
    Write-Host '  This happens when the files came from an internet ZIP download.' -ForegroundColor Yellow
    Write-Host '  Fix: delete this folder, right-click the downloaded ZIP > Properties >' -ForegroundColor Gray
    Write-Host '       tick "Unblock" > OK, then extract it again. (Or download it with "git clone".)' -ForegroundColor Gray
    Write-Host ''
    Read-Host 'Press Enter to close' | Out-Null
    exit
}

$engineDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir     = Split-Path -Parent $engineDir
$port        = 8765
$recovery    = Join-Path $engineDir 'Recovery.ps1'
$logDir      = Join-Path $rootDir "Logs\$env:COMPUTERNAME"
$configDir   = Join-Path $rootDir 'Config'
$backupDir   = Join-Path $rootDir "Backups\$env:COMPUTERNAME"
$reportsDir  = Join-Path $rootDir 'Reports'
$settingsFile = Join-Path $configDir 'settings.json'
$familyFile  = Join-Path $configDir 'family settings.json'
$token       = ([guid]::NewGuid().ToString('N')) + ([guid]::NewGuid().ToString('N'))
$script:familyUnlocked = $false

# ------------------------------------------------------------------------------
# Activity log: Logs\<PC name>\toolkit <date>.log (kept 30 days)
# ------------------------------------------------------------------------------
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Get-ChildItem -LiteralPath $logDir -Filter '*.log' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force
function Write-Log([string]$Level, [string]$Message) {
    $file = Join-Path $logDir ("toolkit {0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Level, ($Message -replace '[\r\n]+', ' | ')
    try { Add-Content -LiteralPath $file -Value $line -Encoding UTF8 } catch {}
}

# ------------------------------------------------------------------------------
# Start the listener. Port 8765 normally; if something else has it, pick a random free
# port (the address changes each time, and it is still only reachable from this PC).
# ------------------------------------------------------------------------------
function Start-Listener([int]$p) {
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://127.0.0.1:$p/")
    try { $l.Start(); return $l } catch { return $null }
}
$listener = Start-Listener $port
if (-not $listener) {
    try {
        $page = Invoke-WebRequest -Uri "http://127.0.0.1:$port/" -UseBasicParsing -TimeoutSec 3
        if ($page.Content -match 'toolkit-token') {
            Write-Host "The toolkit is already running - opening it in your browser." -ForegroundColor Green
            Start-Process "http://127.0.0.1:$port/"
            exit
        }
    } catch {}
    for ($i = 0; $i -lt 5 -and -not $listener; $i++) {
        $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
        $probe.Start(); $port = $probe.LocalEndpoint.Port; $probe.Stop()
        $listener = Start-Listener $port
    }
    if (-not $listener) { Write-Host 'Could not open a local port. Restart the PC and try again.' -ForegroundColor Red; Write-Log 'ERROR' 'Could not open any local port'; Read-Host 'Press Enter to close' | Out-Null; exit }
    Write-Host "Port 8765 was busy, so the toolkit is using port $port instead." -ForegroundColor Yellow
}
$prefix = "http://127.0.0.1:$port/"
Write-Log 'INFO' "Toolkit started on $prefix by $env:USERNAME (PowerShell $($PSVersionTable.PSVersion), $((Get-CimInstance Win32_OperatingSystem).Caption))"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  PC Security Toolkit v3.1 is running" -ForegroundColor Green
Write-Host "  URL: $prefix" -ForegroundColor White
Write-Host "  Keep this window open while you use the dashboard." -ForegroundColor Gray
Write-Host "  If anything goes wrong, double-click 'RECOVERY MODE Windows.bat'." -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Cyan

Start-Process $prefix

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
function Send-Json($res, $obj, [int]$status = 200) {
    $json = $obj | ConvertTo-Json -Depth 8 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $res.StatusCode = $status
    $res.ContentType = "application/json; charset=utf-8"
    $res.Headers.Add('Cache-Control', 'no-store')
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
    if ($obj -is [hashtable] -and $obj.ContainsKey('message') -and $script:currentPath -ne '/api/client-log') {
        Write-Log $(if ($obj.ok) { 'INFO' } else { 'WARN' }) "$($script:currentPath): $($obj.message)"
    }
}

function Read-Body($req) {
    try {
        $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
        $text = $reader.ReadToEnd()
        if (-not $text) { return [pscustomobject]@{} }
        return ($text | ConvertFrom-Json)
    } catch { return [pscustomobject]@{} }
}

function Quote-PS([string]$s) { return "'" + ($s -replace "'", "''") + "'" }

function Start-Elevated([string]$scriptText, [string]$fileName, [string]$label) {
    $tmp = Join-Path $env:TEMP $fileName
    $pre = ''
    if ($label -and (Test-Path -LiteralPath $recovery)) {
        $pre = "`$toolkitRecovery = $(Quote-PS $recovery)`r`n" +
               "Write-Host 'Saving a recovery snapshot first (you can undo this in Recovery Mode)...' -ForegroundColor Cyan`r`n" +
               "& `$toolkitRecovery -Mode Snapshot -Label $(Quote-PS ('Before ' + $label)) -Quiet | Out-Null`r`n`r`n"
    }
    # Record everything the script prints into the Logs folder, for troubleshooting.
    $runLog = Join-Path $logDir ("run {0} {1}.log" -f (Get-Date -Format 'yyyy-MM-dd HH-mm-ss'), (($label -replace '[^A-Za-z0-9 \-]', '').Trim()))
    $pre = "Start-Transcript -LiteralPath $(Quote-PS $runLog) -Append | Out-Null`r`n" + $pre
    $post = "`r`n`r`nStop-Transcript | Out-Null`r`nWrite-Host 'A full log of this run is saved in the toolkit Logs folder.' -ForegroundColor DarkGray`r`n"
    Write-Log 'INFO' "Starting elevated script '$label' (log: $([IO.Path]::GetFileName($runLog)))"
    Set-Content -LiteralPath $tmp -Value ($pre + $scriptText + $post) -Encoding UTF8
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$tmp`"" -ErrorAction Stop
        return @{ ok = $true; message = "Started! Click 'Yes' on the Windows permission prompt." }
    } catch {
        return @{ ok = $false; message = "Cancelled - Windows permission was not given." }
    }
}

function Start-Recovery([string]$mode, [string]$snapshot = '') {
    $argList = "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$recovery`" -Mode $mode"
    if ($snapshot) { $argList += " -SnapshotPath `"$snapshot`"" }
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -ErrorAction Stop
        return @{ ok = $true; message = "Recovery started - click 'Yes' on the Windows prompt and watch the blue window." }
    } catch {
        return @{ ok = $false; message = "Cancelled - Windows permission was not given." }
    }
}

function Find-Tool([string[]]$candidates, [string]$commandName) {
    foreach ($c in $candidates) { $p = Join-Path $rootDir $c; if (Test-Path -LiteralPath $p) { return $p } }
    if ($commandName) { $cmd = Get-Command $commandName -ErrorAction SilentlyContinue; if ($cmd) { return $cmd.Source } }
    return $null
}
function Find-HitmanPro {
    $p = Find-Tool @('Tools\HitmanPro x64.exe', 'Tools\HitmanPro_x64.exe') $null
    if (-not $p -and (Test-Path 'C:\Program Files\HitmanPro\HitmanPro.exe')) { $p = 'C:\Program Files\HitmanPro\HitmanPro.exe' }
    return $p
}
function Find-Adb { return (Find-Tool @('Tools\adb\adb.exe') 'adb') }
function Find-IDevice([string]$exe) { return (Find-Tool @("Tools\libimobiledevice\$exe.exe", "Tools\iPad Tools\$exe.exe") $exe) }

# Runs a command-line tool with a time limit so a phone waiting on "Trust" can't freeze the server.
function Invoke-Tool([string]$exe, [string]$arguments, [int]$timeoutMs = 8000) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe; $psi.Arguments = $arguments
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = Split-Path -Parent $exe
        $p = [System.Diagnostics.Process]::Start($psi)
        $outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($timeoutMs)) { try { $p.Kill() } catch {}; return @{ ok = $false; out = ''; err = 'timed out' } }
        return @{ ok = ($p.ExitCode -eq 0); out = $outTask.Result; err = $errTask.Result; blocked = $false }
    } catch {
        $msg = $_.Exception.Message
        if ($_.Exception.InnerException) { $msg = $_.Exception.InnerException.Message }
        # Windows Smart App Control / App Control blocks unsigned programs (error 4551)
        $blocked = ($msg -match 'Application Control|App Control|4551|blocked')
        return @{ ok = $false; out = ''; err = $msg; blocked = $blocked }
    }
}

function Get-AdminMembers {
    $out = @(net localgroup Administrators 2>$null)
    $members = @(); $inList = $false
    foreach ($l in $out) {
        if ($l -match '^-{5,}') { $inList = $true; continue }
        if ($inList -and $l.Trim() -and $l -notmatch '^The command completed') { $members += $l.Trim() }
    }
    return $members
}

function Get-LogonHours([string]$User) {
    $vals = @(); $collect = $false
    foreach ($l in @(net user "$User" 2>$null)) {
        if ($l -match '^Logon hours allowed\s+(.*)$') { $collect = $true; $vals += $Matches[1].Trim(); continue }
        if ($collect) { if ($l -match '^\s{5,}(\S.*)$') { $vals += $Matches[1].Trim() } else { break } }
    }
    return (($vals | Where-Object { $_ }) -join '|')
}

function Read-JsonFile([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}
function Write-JsonFile([string]$path, $obj) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    $obj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Get-PinHash([string]$pin, [string]$saltB64) {
    $salt = [Convert]::FromBase64String($saltB64)
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pin, $salt, 100000)
    return [Convert]::ToBase64String($kdf.GetBytes(32))
}

function Get-FolderSizeGB([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $sum = (Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    return [math]::Round(([double]$sum) / 1GB, 2)
}

# ------------------------------------------------------------------------------
# Windows scan
# ------------------------------------------------------------------------------
function Invoke-FastScan {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $drive = Get-PSDrive C
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    $totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
    $freePct = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $totalRAM = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)

    $mp = Get-MpComputerStatus
    $mpPref = Get-MpPreference
    $llmnr = (Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient").EnableMulticast
    $wifiNB = (Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" | Where-Object { $_.Description -match 'Wi-Fi|Wireless|WLAN' } | Select-Object -First 1).TcpipNetbiosOptions
    $ra = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance").fAllowToGetHelp
    $autorun = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer").NoDriveTypeAutoRun
    $recall = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI").DisableAIDataAnalysis
    $typing = (Get-ItemProperty "HKCU:\Software\Microsoft\InputPersonalization").RestrictImplicitTextCollection
    $bingOff = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer").DisableSearchBoxSuggestions
    $clipHist = (Get-ItemProperty "HKCU:\Software\Microsoft\Clipboard").EnableClipboardHistory
    $adId = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo").Enabled
    $ntlm = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa").LmCompatibilityLevel
    $doMode = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization").DODownloadMode

    # New in v3: firewall, UAC, disk encryption, Secure Boot, updates, Wi-Fi, guest account
    $fwOff = @(Get-NetFirewallProfile | Where-Object { "$($_.Enabled)" -ne 'True' } | ForEach-Object { $_.Name })
    $uacOn = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA -eq 1)
    $bl = $null
    try { $bl = (New-Object -ComObject Shell.Application).NameSpace('C:').Self.ExtendedProperty('System.Volume.BitLockerProtection') } catch {}
    $bitlockerOn = ($bl -in @(1, 3, 6))
    $bitlockerKnown = ($null -ne $bl -and $bl -ne 0)
    $secureBoot = ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State').UEFISecureBootEnabled -eq 1)
    $sigAge = $mp.AntivirusSignatureAge
    $lastPatch = Get-CimInstance Win32_QuickFixEngineering | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
    $patchDays = $null
    if ($lastPatch) { $patchDays = [int]((Get-Date) - [datetime]$lastPatch.InstalledOn).TotalDays }
    $pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    $guestOn = [bool](Get-LocalUser -Name 'Guest' -ErrorAction SilentlyContinue).Enabled
    $admins = @(Get-AdminMembers)
    $dailyAdmin = [bool]($admins | Where-Object { ($_ -split '\\')[-1] -ieq $env:USERNAME })

    $wifi = @{ connected = $false; ssid = ''; auth = '' }
    $wl = @(netsh.exe wlan show interfaces 2>$null)
    foreach ($l in $wl) {
        if ($l -match '^\s+State\s+:\s+(.+)$') { $wifi.connected = ($Matches[1].Trim() -eq 'connected') }
        elseif ($l -match '^\s+SSID\s+:\s+(.*)$') { $wifi.ssid = $Matches[1].Trim() }
        elseif ($l -match '^\s+Authentication\s+:\s+(.+)$') { $wifi.auth = $Matches[1].Trim() }
    }

    $startupItems = @(Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location)

    $procMap = @{}
    Get-Process | ForEach-Object { $procMap[$_.Id] = $_.Name }

    $listening = @(Get-NetTCPConnection -State Listen | Where-Object { $_.LocalAddress -notin @("127.0.0.1", "::1") } | ForEach-Object {
        @{ LocalAddress = $_.LocalAddress; LocalPort = $_.LocalPort; Process = $(if ($procMap[$_.OwningProcess]) { $procMap[$_.OwningProcess] } else { "System" }) }
    } | Sort-Object { $_.LocalPort } -Unique)

    $outbound = @(Get-NetTCPConnection -State Established | Where-Object { $_.RemoteAddress -notin @("127.0.0.1", "::1") } | ForEach-Object {
        @{ RemoteAddress = $_.RemoteAddress; RemotePort = $_.RemotePort; Process = $(if ($procMap[$_.OwningProcess]) { $procMap[$_.OwningProcess] } else { "System" }) }
    } | Sort-Object { $_.Process } -Unique | Select-Object -First 25)

    $ifeoHijacks = @()
    Get-ChildItem -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" | ForEach-Object {
        $p = Get-ItemProperty -LiteralPath $_.PSPath
        if ($p.Debugger) { $ifeoHijacks += "$($_.PSChildName) -> $($p.Debugger)" }
    }
    $sethcValid = ((Get-AuthenticodeSignature "C:\Windows\System32\sethc.exe").Status -eq "Valid")
    $utilmanValid = ((Get-AuthenticodeSignature "C:\Windows\System32\utilman.exe").Status -eq "Valid")

    $largeDownloads = @(Get-ChildItem "$env:USERPROFILE\Downloads" -File -Force | Where-Object { $_.Length -ge 100MB } | ForEach-Object {
        @{ Name = $_.Name; Type = "File"; SizeGB = [math]::Round($_.Length / 1GB, 2) }
    } | Sort-Object { $_.SizeGB } -Descending | Select-Object -First 12)

    $caches = @()
    foreach ($c in @(
        @{ Name = "User Temp"; Path = "$env:LOCALAPPDATA\Temp"; Cleanable = $true },
        @{ Name = "npm cache"; Path = "$env:LOCALAPPDATA\npm-cache"; Cleanable = $true },
        @{ Name = ".cache folder"; Path = "$env:USERPROFILE\.cache"; Cleanable = $true },
        @{ Name = "NuGet packages"; Path = "$env:USERPROFILE\.nuget\packages"; Cleanable = $true },
        @{ Name = "Playwright browsers"; Path = "$env:LOCALAPPDATA\ms-playwright"; Cleanable = $true },
        @{ Name = "Windows.old (old Windows install)"; Path = "C:\Windows.old"; Cleanable = $false },
        @{ Name = "C:\ESD (upgrade files)"; Path = "C:\ESD"; Cleanable = $false }
    )) {
        if (Test-Path $c.Path) { $caches += @{ Name = $c.Name; Key = $c.Path; SizeGB = $null; Cleanable = $c.Cleanable } }
    }

    $riskyExts = @()
    $knownRisky = @{
        "amnbcmdbanbkjhnfoeceemmmdiepnbpp" = "Honey (Coupon/Cookie Tracker)"
        "pefhciejnkgdgoahgfeklebcbpmhnhhd" = "Coupert (Coupon/Cookie Tracker)"
        "klekeajafkkpokaofllcadenjdckhinm" = "McAfee Web Boost (OEM Bloatware)"
        "fheoggkfdfchfphceeifdbepaooicaho" = "McAfee WebAdvisor (OEM Bloatware)"
        "cjboohgkgchdnfnjiaggdbkdmpieoagi" = "PDF Editor for Docs (Ad/Upload Risk)"
    }
    foreach ($b in @(
        @{ Name = "Edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions" },
        @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions" }
    )) {
        if (Test-Path $b.Path) {
            Get-ChildItem $b.Path -Directory | ForEach-Object {
                if ($knownRisky.ContainsKey($_.Name)) { $riskyExts += @{ Browser = $b.Name; Id = $_.Name; Name = $knownRisky[$_.Name] } }
            }
        }
    }

    $hasHmp = [bool](Find-HitmanPro)

    $ollamaUp = $false
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect("127.0.0.1", 11434, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(50, $false)) { $ollamaUp = $tcp.Connected }
        $tcp.Close()
    } catch {}

    # Offline risk score (0 - 100)
    $score = 100
    $findings = @()
    $riskyPortList = @($listening | Where-Object { $_.LocalPort -in @(21, 22, 23, 139, 623, 3306, 3389, 5985, 8090, 16992, 33060) })

    if ($freePct -lt 10) { $score -= 20; $findings += @{ severity = "CRITICAL"; title = "Low SSD space ($freeGB GB / $freePct% free)"; fix = "Clean safe caches (Storage tab) and run SSD ReTrim." } }
    if (-not $mp.RealTimeProtectionEnabled) { $score -= 25; $findings += @{ severity = "CRITICAL"; title = "Windows Defender Real-Time Protection is OFF"; fix = "Turn on Defender Real-Time, PUA and Network Protection (Script Builder)." } }
    if ($fwOff.Count -gt 0) { $score -= 15; $findings += @{ severity = "CRITICAL"; title = "Windows Firewall is OFF for: $($fwOff -join ', ')"; fix = "Open Windows Security > Firewall & network protection and turn every profile on." } }
    if (-not $uacOn) { $score -= 15; $findings += @{ severity = "CRITICAL"; title = "User Account Control (UAC) is turned off"; fix = "Any program can silently get admin rights. Turn UAC back on in Control Panel > User Accounts." } }
    if ($mpPref.EnableNetworkProtection -ne 1) { $score -= 10; $findings += @{ severity = "MEDIUM"; title = "Defender Network Protection disabled"; fix = "Enable Network Protection to block malicious domains across all apps." } }
    if ($null -ne $sigAge -and $sigAge -gt 7) { $score -= 8; $findings += @{ severity = "HIGH"; title = "Virus definitions are $sigAge days old"; fix = "Open Windows Security > Virus & threat protection > Check for updates." } }
    if ($null -ne $patchDays -and $patchDays -gt 45) { $score -= 10; $findings += @{ severity = "HIGH"; title = "No Windows updates installed for $patchDays days"; fix = "Open Settings > Windows Update and install everything." } }
    if ($wifi.connected -and $wifi.auth -eq 'Open') { $score -= 10; $findings += @{ severity = "HIGH"; title = "Connected to an OPEN Wi-Fi network with no password ($($wifi.ssid))"; fix = "Anyone nearby can see unencrypted traffic. Use a VPN or phone hotspot, and run Travel Mode." } }
    if ($llmnr -ne 0) { $score -= 10; $findings += @{ severity = "HIGH"; title = "LLMNR poisoning enabled"; fix = "Disable LLMNR (EnableMulticast = 0) for safe public Wi-Fi." } }
    if ($wifiNB -ne 2 -and $null -ne $wifiNB) { $score -= 10; $findings += @{ severity = "HIGH"; title = "NetBIOS enabled on Wi-Fi (port 139)"; fix = "Set TcpipNetbiosOptions = 2 on the Wi-Fi adapter." } }
    if ($bitlockerKnown -and -not $bitlockerOn) { $score -= 8; $findings += @{ severity = "MEDIUM"; title = "Drive C: is not encrypted (BitLocker / Device Encryption off)"; fix = "If this laptop is stolen, files can be read. Turn on BitLocker or Device Encryption in Settings." } }
    if (-not $secureBoot) { $score -= 5; $findings += @{ severity = "MEDIUM"; title = "Secure Boot is off"; fix = "Turn Secure Boot on in the PC's UEFI/BIOS settings to block boot-level malware." } }
    if ($guestOn) { $score -= 8; $findings += @{ severity = "MEDIUM"; title = "The Guest account is enabled"; fix = "Disable it: net user Guest /active:no" } }
    if ($ntlm -ne 5) { $score -= 5; $findings += @{ severity = "MEDIUM"; title = "NTLMv1 downgrade allowed"; fix = "Enforce NTLMv2 only (LmCompatibilityLevel = 5)." } }
    if ($autorun -ne 255) { $score -= 8; $findings += @{ severity = "MEDIUM"; title = "USB AutoRun not disabled"; fix = "Set NoDriveTypeAutoRun = 255." } }
    if ($recall -ne 1) { $score -= 7; $findings += @{ severity = "MEDIUM"; title = "Windows Recall screenshot policy open"; fix = "Block DisableAIDataAnalysis = 1." } }
    if ($typing -ne 1) { $score -= 5; $findings += @{ severity = "MEDIUM"; title = "Windows typing harvesting active"; fix = "Set RestrictImplicitTextCollection = 1." } }
    if ($ra -eq 1) { $score -= 5; $findings += @{ severity = "LOW"; title = "Windows Remote Assistance enabled"; fix = "Set fAllowToGetHelp = 0." } }
    if ($pendingReboot) { $score -= 3; $findings += @{ severity = "LOW"; title = "A restart is waiting to finish installing updates"; fix = "Restart the PC so security updates take effect." } }
    if ($dailyAdmin) { $findings += @{ severity = "LOW"; title = "You use an administrator account every day"; fix = "Safer: a Standard account for daily use and a separate admin account. (Kids should always be Standard - see Family Plan.)" } }
    if ($riskyPortList.Count -gt 0) {
        $pStr = ($riskyPortList | ForEach-Object { "$($_.LocalPort) ($($_.Process))" }) -join ", "
        $score -= 15; $findings += @{ severity = "CRITICAL"; title = "Risky listening ports: $pStr"; fix = "Block on public Wi-Fi or disable unused services." }
    }
    if ($riskyExts.Count -gt 0) { $score -= 5; $findings += @{ severity = "MEDIUM"; title = "$($riskyExts.Count) tracking/bloatware browser extensions found"; fix = "Remove Honey, Coupert, McAfee, or untrusted PDF extensions." } }
    if ($ifeoHijacks.Count -gt 0 -or -not $sethcValid -or -not $utilmanValid) {
        $score -= 30; $findings += @{ severity = "CRITICAL"; title = "Possible persistence/backdoor tampering detected!"; fix = "Run HitmanPro immediately and inspect IFEO/System32." }
    }
    if ($score -lt 0) { $score = 0 }

    return @{
        platform = 'Windows'
        hostname = $env:COMPUTERNAME
        user = $env:USERNAME
        os = $os.Caption
        lastBoot = $os.LastBootUpTime.ToString("g")
        score = $score
        freeGB = $freeGB; totalGB = $totalGB; freePct = $freePct
        freeRAM = $freeRAM; totalRAM = $totalRAM
        startupItems = $startupItems
        listeningPorts = $listening
        outboundConns = $outbound
        largeDownloads = $largeDownloads
        caches = $caches
        riskyExts = $riskyExts
        ifeoHijacks = $ifeoHijacks
        stickyKeysClean = ($sethcValid -and $utilmanValid)
        hitmanProAvailable = $hasHmp
        ollamaAvailable = $ollamaUp
        wifi = $wifi
        patchDays = $patchDays
        sigAgeDays = $sigAge
        pendingReboot = $pendingReboot
        controls = @{
            defenderRealTime = [bool]$mp.RealTimeProtectionEnabled
            defenderNetProt = ($mpPref.EnableNetworkProtection -eq 1)
            firewallOn = ($fwOff.Count -eq 0)
            uacOn = $uacOn
            bitlockerOn = $bitlockerOn
            secureBootOn = $secureBoot
            llmnrOff = ($llmnr -eq 0)
            wifiNetbiosOff = ($wifiNB -eq 2)
            ntlmv2Only = ($ntlm -eq 5)
            usbAutorunOff = ($autorun -eq 255)
            remoteAssistOff = ($ra -eq 0)
            recallBlocked = ($recall -eq 1)
            typingBlocked = ($typing -eq 1)
            bingSearchOff = ($bingOff -eq 1)
            clipboardOff = ($clipHist -eq 0)
            adIdOff = ($adId -eq 0)
            doSvcHttpOnly = ($doMode -eq 0)
        }
        findings = $findings
    }
}

# ------------------------------------------------------------------------------
# Mobile: Android (adb) + iPad / iPhone (USB detection + libimobiledevice)
# ------------------------------------------------------------------------------
function Get-AppleInfo([string]$tool, [string]$udid, [string]$domain = '') {
    $a = "-u $udid"
    if ($domain) { $a += " -q $domain" }
    $r = Invoke-Tool $tool $a 8000
    $map = @{}
    foreach ($line in ($r.out -split "`r?`n")) { if ($line -match '^([A-Za-z0-9]+):\s?(.*)$') { $map[$Matches[1]] = $Matches[2].Trim() } }
    return @{ ok = $r.ok; map = $map; err = $r.err }
}

function Invoke-MobileScan {
    # ---------- Android ----------
    $adbPath = Find-Adb
    $android = @{ available = [bool]$adbPath; connected = $false; status = "No Android device detected"; model = ''; version = ''; patch = ''; apps = @() }
    if ($adbPath) {
        $r = Invoke-Tool $adbPath 'devices' 8000
        $line = ($r.out -split "`r?`n" | Where-Object { $_ -match "`t(device|unauthorized)" } | Select-Object -First 1)
        if ($line -match 'unauthorized') {
            $android.status = "Android plugged in - tap 'Allow USB debugging' on the phone screen"
        } elseif ($line) {
            $android.connected = $true
            $android.status = "Connected and authorized"
            $android.model = (Invoke-Tool $adbPath 'shell getprop ro.product.model').out.Trim()
            $android.version = (Invoke-Tool $adbPath 'shell getprop ro.build.version.release').out.Trim()
            $android.patch = (Invoke-Tool $adbPath 'shell getprop ro.build.version.security_patch').out.Trim()
            $android.apps = @(((Invoke-Tool $adbPath 'shell pm list packages -3' 15000).out -split "`r?`n") | Where-Object { $_ -match '^package:' } | ForEach-Object { $_ -replace '^package:', '' } | Sort-Object)
        }
    }

    # ---------- iPad / iPhone ----------
    $pnp = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue)
    $usbApple = @($pnp | Where-Object { $_.PNPDeviceID -like 'USB\VID_05AC*' })
    $wpdApple = @($pnp | Where-Object { $_.PNPClass -eq 'WPD' -and $_.Name -match 'iPad|iPhone|iPod|Apple' })
    $btApple = @($pnp | Where-Object { $_.PNPDeviceID -like 'BTH*' -and $_.Name -match 'iPad|iPhone' })
    $names = @(($usbApple + $wpdApple) | ForEach-Object { $_.Name } | Where-Object { $_ } | Select-Object -Unique)
    $kind = 'Apple device'
    $allNames = ($names -join ' ')
    $pids = ($usbApple | ForEach-Object { $_.PNPDeviceID }) -join ' '
    if ($allNames -match 'iPad' -or $pids -match 'PID_12AB') { $kind = 'iPad' }
    elseif ($allNames -match 'iPhone' -or $pids -match 'PID_12A8') { $kind = 'iPhone' }
    elseif ($allNames -match 'iPod') { $kind = 'iPod' }
    elseif ((($btApple | ForEach-Object { $_.Name }) -join ' ') -match 'iPad') { $kind = 'iPad' }
    elseif ((($btApple | ForEach-Object { $_.Name }) -join ' ') -match 'iPhone') { $kind = 'iPhone' }

    $amdsSvc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Apple Mobile Device' } | Select-Object -First 1
    $toolId = Find-IDevice 'idevice_id'
    $toolInfo = Find-IDevice 'ideviceinfo'
    $apple = @{
        usbConnected = ($usbApple.Count -gt 0 -or $wpdApple.Count -gt 0)
        kind = $kind
        usbNames = $names
        bluetoothOnly = ($btApple.Count -gt 0 -and $usbApple.Count -eq 0 -and $wpdApple.Count -eq 0)
        bluetoothNames = @($btApple | ForEach-Object { $_.Name } | Select-Object -Unique)
        appleDriver = [bool]$amdsSvc
        appleDriverRunning = ($amdsSvc -and $amdsSvc.Status -eq 'Running')
        toolsFound = [bool]($toolId -and $toolInfo)
        toolsBlocked = $false
        trusted = $false
        status = ''
        info = $null
        apps = @()
        findings = @()
    }

    if ($apple.toolsFound) {
        $probe = Invoke-Tool $toolId '-h' 4000
        if ($probe.blocked) { $apple.toolsBlocked = $true }
    }

    if (-not $apple.usbConnected) {
        $apple.status = if ($apple.bluetoothOnly) { "Only paired over Bluetooth - plug the $kind in with a USB cable to scan it" } else { 'No iPad or iPhone found on USB' }
    } elseif (-not $apple.toolsFound) {
        $apple.status = "$kind connected over USB (basic mode)"
    } elseif ($apple.toolsBlocked) {
        $apple.status = "$kind connected over USB (basic mode - Windows Smart App Control is blocking the iPad tools)"
    } else {
        $ids = @(((Invoke-Tool $toolId '-l' 6000).out -split "`r?`n") | Where-Object { $_ -match '^[0-9A-Fa-f\-]{20,}$' })
        if ($ids.Count -eq 0) {
            $apple.status = if ($apple.appleDriverRunning) { "Unlock the $kind and tap 'Trust This Computer', then scan again" } else { "Install the free Apple Devices app (Microsoft Store) so Windows can talk to the $kind" }
        } else {
            $udid = $ids[0]
            $basic = Get-AppleInfo $toolInfo $udid
            if (-not $basic.ok -or $basic.map.Count -eq 0) {
                $apple.status = "Unlock the $kind and tap 'Trust This Computer', then scan again"
            } else {
                $m = $basic.map
                $bat = (Get-AppleInfo $toolInfo $udid 'com.apple.mobile.battery').map
                $disk = (Get-AppleInfo $toolInfo $udid 'com.apple.disk_usage').map
                $bk = (Get-AppleInfo $toolInfo $udid 'com.apple.mobile.backup').map
                $total = [double]($disk['TotalDiskCapacity']); $avail = [double]($disk['AmountDataAvailable'])
                $serial = [string]$m['SerialNumber']
                $apple.trusted = $true
                $apple.status = "$($m['DeviceName']) connected and trusted"
                $apple.info = @{
                    name = $m['DeviceName']; model = $m['ProductType']; ios = $m['ProductVersion']; build = $m['BuildVersion']
                    serialEnd = $(if ($serial.Length -ge 4) { $serial.Substring($serial.Length - 4) } else { '' })
                    passcode = ($m['PasswordProtected'] -eq 'true')
                    activated = $m['ActivationState']
                    battery = $bat['BatteryCurrentCapacity']; charging = ($bat['BatteryIsCharging'] -eq 'true')
                    totalGB = $(if ($total) { [math]::Round($total / 1e9, 1) } else { $null })
                    freeGB = $(if ($avail) { [math]::Round($avail / 1e9, 1) } else { $null })
                    backupEncrypted = ($bk['WillEncrypt'] -eq 'true')
                    udid = $udid
                }
                $major = 0; [void][int]::TryParse(([string]$m['ProductVersion']).Split('.')[0], [ref]$major)
                if (-not $apple.info.passcode) { $apple.findings += @{ severity = 'CRITICAL'; title = 'No passcode is set'; fix = 'Settings > Face ID/Touch ID & Passcode > Turn Passcode On. Without it anyone can open the device and your data is not encrypted.' } }
                if ($major -gt 0 -and $major -lt 26) { $apple.findings += @{ severity = 'HIGH'; title = "iPadOS/iOS $($m['ProductVersion']) is out of date"; fix = 'Settings > General > Software Update. Old versions have known security holes.' } }
                if (-not $apple.info.backupEncrypted) { $apple.findings += @{ severity = 'MEDIUM'; title = 'Computer backups are not encrypted'; fix = 'Use "Back up to this USB" with encryption, or tick "Encrypt local backup" in the Apple Devices app. Encrypted backups also save passwords and Health data.' } }
                if ($total -and $avail -and ($avail / $total) -lt 0.1) { $apple.findings += @{ severity = 'MEDIUM'; title = "Storage almost full ($($apple.info.freeGB) GB free)"; fix = 'Settings > General > iPad Storage. Updates need free space to install.' } }

                $inst = Find-IDevice 'ideviceinstaller'
                if ($inst) {
                    $r = Invoke-Tool $inst "-u $udid -l" 15000
                    if (-not $r.ok -or $r.out -match 'Usage|ERROR') { $r = Invoke-Tool $inst "-u $udid list --user" 15000 }
                    foreach ($line in ($r.out -split "`r?`n")) {
                        if ($line -match '^([A-Za-z0-9.\-]+),\s*"?([^",]*)"?,\s*"?([^"]*)"?') {
                            if ($Matches[1] -ne 'CFBundleIdentifier') { $apple.apps += @{ id = $Matches[1]; version = $Matches[2]; name = $Matches[3] } }
                        }
                    }
                }
            }
        }
    }
    return @{ android = $android; apple = $apple; adbAvailable = [bool]$adbPath }
}

# ------------------------------------------------------------------------------
# Family Plan status
# ------------------------------------------------------------------------------
$familyDnsMap = @{
    '1.1.1.3' = 'Cloudflare for Families'; '1.0.0.3' = 'Cloudflare for Families'
    '185.228.168.168' = 'CleanBrowsing Family'; '185.228.169.168' = 'CleanBrowsing Family'
    '208.67.222.123' = 'OpenDNS FamilyShield'; '208.67.220.123' = 'OpenDNS FamilyShield'
}

function Get-FamilyStatus {
    $cfg = Read-JsonFile $familyFile
    $hasPin = [bool]($cfg -and $cfg.pinHash)
    $locked = ($hasPin -and -not $script:familyUnlocked)

    $hostsText = [IO.File]::ReadAllText((Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'))
    $blockCount = 0
    if ($hostsText -match '(?s)# >>> PC Security Toolkit Family Plan >>>(.*?)# <<< PC Security Toolkit Family Plan <<<') {
        $blockCount = @($Matches[1] -split "`r?`n" | Where-Object { $_ -match '^0\.0\.0\.0\s' }).Count
    }

    $dnsProviders = @()
    foreach ($a in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
        $servers = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
        $prov = ($servers | ForEach-Object { $familyDnsMap[$_] } | Where-Object { $_ } | Select-Object -First 1)
        $dnsProviders += @{ adapter = $a.Name; up = ($a.Status -eq 'Up'); servers = $servers; provider = $(if ($prov) { $prov } else { '' }) }
    }

    $pol = @{}
    foreach ($b in @(@('edge', 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'), @('chrome', 'HKLM:\SOFTWARE\Policies\Google\Chrome'))) {
        $p = Get-ItemProperty -LiteralPath $b[1] -ErrorAction SilentlyContinue
        $list = Get-Item -LiteralPath "$($b[1])\URLBlocklist" -ErrorAction SilentlyContinue
        $pol[$b[0]] = @{
            safeSearch = ($p.ForceGoogleSafeSearch -eq 1)
            youtube = [int]$p.ForceYouTubeRestrict
            privateOff = ($p.InPrivateModeAvailability -eq 1 -or $p.IncognitoModeAvailability -eq 1)
            blockedRules = $(if ($list) { $list.ValueCount } else { 0 })
        }
    }

    $admins = @(Get-AdminMembers)
    $users = @()
    foreach ($u in @(Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { $_.Enabled })) {
        $isAdmin = [bool]($admins | Where-Object { ($_ -split '\\')[-1] -ieq $u.Name })
        $users += @{ name = $u.Name; fullName = $u.FullName; isAdmin = $isAdmin; isCurrent = ($u.Name -ieq $env:USERNAME); hours = (Get-LogonHours $u.Name) }
    }

    $tasks = @()
    try {
        $svc = New-Object -ComObject Schedule.Service; $svc.Connect()
        $tasks = @($svc.GetFolder('\PC Security Toolkit').GetTasks(1) | ForEach-Object { $_.Name })
    } catch {}

    $settings = $null
    if ($cfg -and -not $locked) {
        $settings = $cfg | Select-Object -Property * -ExcludeProperty pinHash, pinSalt
    }

    return @{
        hasPin = $hasPin
        locked = $locked
        settings = $settings
        hostsBlocked = $blockCount
        dns = $dnsProviders
        policies = $pol
        users = $users
        tasks = $tasks
        adminCount = $admins.Count
        currentUser = $env:USERNAME
    }
}

function Save-FamilySettings($incoming) {
    $cfg = Read-JsonFile $familyFile
    $pinHash = $null; $pinSalt = $null
    if ($cfg) { $pinHash = $cfg.pinHash; $pinSalt = $cfg.pinSalt }
    $obj = [ordered]@{}
    foreach ($p in $incoming.PSObject.Properties) { if ($p.Name -notin @('pinHash', 'pinSalt')) { $obj[$p.Name] = $p.Value } }
    $obj['savedAt'] = (Get-Date).ToString('s')
    if ($pinHash) { $obj['pinHash'] = $pinHash; $obj['pinSalt'] = $pinSalt }
    Write-JsonFile $familyFile $obj
}

# ------------------------------------------------------------------------------
# Request loop
# ------------------------------------------------------------------------------
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath
        $script:currentPath = $path
        $method = $req.HttpMethod

        try {
            # Only answer requests addressed to this exact local server.
            $hostHeader = $req.Headers['Host']
            if ($hostHeader -notin @("127.0.0.1:$port", "localhost:$port")) { $res.StatusCode = 403; $res.Close(); continue }

            if ($path -eq "/" -or $path -eq "/index.html") {
                $htmlFile = Join-Path $engineDir "Live Toolkit.html"
                $content = (Get-Content -LiteralPath $htmlFile -Raw -Encoding UTF8).Replace('%%TOOLKIT-TOKEN%%', $token)
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
                $res.ContentType = "text/html; charset=utf-8"
                $res.Headers.Add('Cache-Control', 'no-store')
                $res.Headers.Add('X-Frame-Options', 'DENY')
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
                continue
            }

            if (-not $path.StartsWith('/api/')) { $res.StatusCode = 404; $res.Close(); continue }
            if ($req.Headers['X-Toolkit-Token'] -ne $token) { Send-Json $res @{ ok = $false; message = 'Missing or wrong toolkit token. Reload the page.' } 403; continue }

            $body = $null
            if ($method -eq 'POST') { $body = Read-Body $req }

            switch ($path) {
                '/api/scan' {
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    $scan = Invoke-FastScan
                    Write-Log 'INFO' ("Scan finished in {0:N1}s: score {1}/100, {2} issue(s): {3}" -f $sw.Elapsed.TotalSeconds, $scan.score, @($scan.findings).Count, ((@($scan.findings) | ForEach-Object { "[$($_.severity)] $($_.title)" }) -join '; '))
                    Send-Json $res $scan
                }

                '/api/logs' {
                    $files = @(Get-ChildItem -LiteralPath $logDir -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 60 | ForEach-Object {
                        @{ name = $_.Name; sizeKB = [math]::Ceiling($_.Length / 1KB); modified = $_.LastWriteTime.ToString('s') }
                    })
                    Send-Json $res @{ files = $files; folder = "Logs\$env:COMPUTERNAME" }
                }

                '/api/log-read' {
                    $file = [string]$body.file
                    $full = Join-Path $logDir $file
                    if ($file -notmatch '^[^\\/:*?"<>|]+\.log$' -or -not (Test-Path -LiteralPath $full)) { Send-Json $res @{ ok = $false; text = 'Log not found.' }; break }
                    $lines = @(Get-Content -LiteralPath $full -Tail 500 -Encoding UTF8 -ErrorAction SilentlyContinue)
                    Send-Json $res @{ ok = $true; text = ($lines -join "`n") }
                }

                '/api/client-log' {
                    $msg = [string]$body.message
                    if ($msg.Length -gt 600) { $msg = $msg.Substring(0, 600) }
                    Write-Log 'BROWSER' $msg
                    Send-Json $res @{ ok = $true }
                }

                '/api/settings' {
                    if ($method -eq 'POST') {
                        $theme = [string]$body.theme
                        if ($theme -notmatch '^[a-z]{2,20}$') { $theme = 'midnight' }
                        Write-JsonFile $settingsFile @{ theme = $theme }
                        Send-Json $res @{ ok = $true }
                    } else {
                        $s = Read-JsonFile $settingsFile
                        Send-Json $res @{ theme = $(if ($s -and $s.theme) { $s.theme } else { 'midnight' }); platform = 'Windows'; computer = $env:COMPUTERNAME }
                    }
                }

                '/api/cache-sizes' {
                    $sizes = @{}
                    foreach ($p in @("$env:LOCALAPPDATA\Temp", "$env:LOCALAPPDATA\npm-cache", "$env:USERPROFILE\.cache", "$env:USERPROFILE\.nuget\packages", "$env:LOCALAPPDATA\ms-playwright", "C:\Windows.old", "C:\ESD")) {
                        $g = Get-FolderSizeGB $p
                        if ($null -ne $g) { $sizes[$p] = $g }
                    }
                    Send-Json $res @{ sizes = $sizes }
                }

                '/api/hitmanpro' {
                    $hmp = Find-HitmanPro
                    if ($hmp) { Start-Process -FilePath $hmp; Send-Json $res @{ ok = $true; message = "Launched HitmanPro." } }
                    else { Send-Json $res @{ ok = $false; message = "HitmanPro was not found in the Tools folder." } }
                }

                '/api/execute' {
                    $label = ([string]$body.label -replace "[^A-Za-z0-9 \-]", '').Trim()
                    if (-not $label) { $label = 'Script Builder' }
                    Send-Json $res (Start-Elevated ([string]$body.script) 'PC Security Toolkit Run.ps1' $label)
                }

                '/api/block-extension' {
                    $extId = [string]$body.id
                    $browser = [string]$body.browser
                    if ($extId -notmatch '^[a-p]{32}$' -or $browser -notin @('Edge', 'Chrome')) { Send-Json $res @{ ok = $false; message = 'That does not look like a browser extension ID.' }; break }
                    $policy = if ($browser -eq 'Edge') { 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist' } else { 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallBlocklist' }
                    $folder = if ($browser -eq 'Edge') { "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions\$extId" } else { "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions\$extId" }
                    $script = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$p = $(Quote-PS $policy)
if (-not (Test-Path -LiteralPath `$p)) { New-Item -Path `$p -Force | Out-Null }
`$existing = @((Get-Item `$p).GetValueNames() | ForEach-Object { (Get-ItemProperty `$p).`$_ })
if (`$existing -notcontains '$extId') {
    `$idx = ((Get-Item `$p).ValueCount) + 1
    Set-ItemProperty `$p -Name "`$idx" -Value '$extId' -Type String -Force
}
Remove-Item $(Quote-PS $folder) -Recurse -Force
Write-Host "Blocked and removed $browser extension $extId. Restart $browser to finish." -ForegroundColor Green
"@
                    Send-Json $res (Start-Elevated $script "Block Extension $extId.ps1" "blocking extension $extId")
                }

                '/api/block-port' {
                    $p = 0
                    if (-not [int]::TryParse([string]$body.port, [ref]$p) -or $p -lt 1 -or $p -gt 65535) { Send-Json $res @{ ok = $false; message = 'Not a valid port.' }; break }
                    $script = @"
New-NetFirewallRule -DisplayName "Toolkit Block Public Port $p" -Direction Inbound -Protocol TCP -LocalPort $p -Action Block -Profile Public -Enabled True -ErrorAction SilentlyContinue | Out-Null
Write-Host "Blocked inbound TCP port $p on public Wi-Fi." -ForegroundColor Green
"@
                    Send-Json $res (Start-Elevated $script "Block Port $p.ps1" "blocking port $p")
                }

                '/api/disable-startup' {
                    $name = [string]$body.name
                    if (-not $name) { Send-Json $res @{ ok = $false; message = 'No startup item given.' }; break }
                    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recovery -Mode Snapshot -Label "Before disabling startup $name" -Quiet | Out-Null
                    $userKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
                    if (Get-ItemProperty -LiteralPath $userKey -Name $name -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -LiteralPath $userKey -Name $name -Force
                        Send-Json $res @{ ok = $true; message = "Disabled startup item '$name'. (Undo it any time in Recovery Mode.)" }
                    } elseif ((Get-ItemProperty -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $name -ErrorAction SilentlyContinue) -or (Get-ItemProperty -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' -Name $name -ErrorAction SilentlyContinue)) {
                        $q = Quote-PS $name
                        $script = "Remove-ItemProperty -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $q -Force -EA 0; Remove-ItemProperty -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' -Name $q -Force -EA 0; Write-Host 'Startup item removed.' -ForegroundColor Green"
                        Send-Json $res (Start-Elevated $script 'Disable Startup.ps1' '')
                    } else {
                        Send-Json $res @{ ok = $false; message = "'$name' starts from the Startup folder or Task Manager. Open Task Manager > Startup apps to turn it off." }
                    }
                }

                '/api/clean-caches' {
                    $before = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
                    foreach ($c in @("$env:LOCALAPPDATA\npm-cache", "$env:USERPROFILE\.cache", "$env:USERPROFILE\.nuget\packages", "$env:LOCALAPPDATA\ms-playwright", "$env:LOCALAPPDATA\Temp")) {
                        if (Test-Path -LiteralPath $c) { Remove-Item "$c\*" -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                    $after = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
                    Send-Json $res @{ ok = $true; message = "Cleaned safe caches. Free space: $before GB -> $after GB." }
                }

                '/api/ollama' {
                    try {
                        $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2
                        $model = $tags.models[0].name
                        $payload = @{ model = $model; prompt = [string]$body.prompt; stream = $false } | ConvertTo-Json
                        $aiRes = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 25
                        Send-Json $res @{ ok = $true; model = $model; answer = $aiRes.response }
                    } catch { Send-Json $res @{ ok = $false; answer = "" } }
                }

                '/api/save-report' {
                    $html = [string]$body.html
                    if ($html.Length -gt 5MB) { Send-Json $res @{ ok = $false; message = 'Report too large.' }; break }
                    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
                    $file = Join-Path $reportsDir ("{0} report {1}.html" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyy-MM-dd HH-mm'))
                    Set-Content -LiteralPath $file -Value $html -Encoding UTF8
                    Send-Json $res @{ ok = $true; message = "Report saved to the USB: Reports\$([IO.Path]::GetFileName($file))" }
                }

                '/api/open' {
                    $what = [string]$body.what
                    $known = $true
                    switch ($what) {
                        'cleanmgr'      { Start-Process cleanmgr.exe }
                        'security'      { Start-Process 'windowsdefender:' }
                        'update'        { Start-Process 'ms-settings:windowsupdate' }
                        'backups'       { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null; Start-Process explorer.exe "`"$backupDir`"" }
                        'reports'       { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null; Start-Process explorer.exe "`"$reportsDir`"" }
                        'logs'          { New-Item -ItemType Directory -Path $logDir -Force | Out-Null; Start-Process explorer.exe "`"$logDir`"" }
                        'family-web'    { Start-Process 'https://account.microsoft.com/family' }
                        'accounts'      { Start-Process 'ms-settings:otherusers' }
                        'apple-devices' { Start-Process 'ms-windows-store://search/?query=Apple%20Devices' }
                        'ipad-tools'    { $d = Join-Path $rootDir 'Tools\libimobiledevice'; New-Item -ItemType Directory -Path $d -Force | Out-Null; Start-Process explorer.exe "`"$d`"" }
                        default         { $known = $false }
                    }
                    if ($known) { Send-Json $res @{ ok = $true; message = 'Opened.' } } else { Send-Json $res @{ ok = $false; message = 'Unknown item.' } }
                }

                '/api/mobile-scan' { Send-Json $res (Invoke-MobileScan) }

                '/api/android-uninstall' {
                    $pkg = [string]$body.pkg
                    $adb = Find-Adb
                    if ($pkg -notmatch '^[A-Za-z0-9_.]+$') { Send-Json $res @{ ok = $false; message = 'Not a valid package name.' } }
                    elseif (-not $adb) { Send-Json $res @{ ok = $false; message = 'adb.exe not found.' } }
                    else { $r = Invoke-Tool $adb "shell pm uninstall --user 0 $pkg" 20000; Send-Json $res @{ ok = $r.ok; message = "Android ($pkg): $($r.out.Trim()) $($r.err.Trim())" } }
                }

                '/api/apple-action' {
                    $action = [string]$body.action
                    $udid = [string]$body.udid
                    if ($udid -and $udid -notmatch '^[0-9A-Fa-f\-]{20,}$') { Send-Json $res @{ ok = $false; message = 'Bad device id.' }; break }
                    $u = if ($udid) { "-u $udid" } else { '' }
                    switch ($action) {
                        'pair' {
                            $t = Find-IDevice 'idevicepair'
                            if (-not $t) { Send-Json $res @{ ok = $false; message = 'idevicepair.exe is not in Tools\libimobiledevice.' }; break }
                            $r = Invoke-Tool $t "$u pair" 15000
                            Send-Json $res @{ ok = $r.ok; message = "$($r.out.Trim()) $($r.err.Trim())".Trim() }
                        }
                        'backup' {
                            $t = Find-IDevice 'idevicebackup2'
                            if (-not $t) { Send-Json $res @{ ok = $false; message = 'idevicebackup2.exe is not in Tools\libimobiledevice.' }; break }
                            $dest = Join-Path $rootDir 'Backups\iPad and iPhone'
                            New-Item -ItemType Directory -Path $dest -Force | Out-Null
                            Start-Process cmd.exe -ArgumentList "/k `"`"$t`" $u backup --full `"$dest`"`""
                            Send-Json $res @{ ok = $true; message = "Backup started in a new window. Keep the device plugged in and unlocked. Saving to Backups\iPad and iPhone on the USB." }
                        }
                        'uninstall' {
                            $t = Find-IDevice 'ideviceinstaller'
                            $bundle = [string]$body.bundle
                            if ($bundle -notmatch '^[A-Za-z0-9.\-]+$') { Send-Json $res @{ ok = $false; message = 'Bad app id.' }; break }
                            if (-not $t) { Send-Json $res @{ ok = $false; message = 'ideviceinstaller.exe is not in Tools\libimobiledevice.' }; break }
                            $r = Invoke-Tool $t "$u -U $bundle" 30000
                            if (-not $r.ok) { $r = Invoke-Tool $t "$u uninstall $bundle" 30000 }
                            Send-Json $res @{ ok = $r.ok; message = "$($r.out.Trim()) $($r.err.Trim())".Trim() }
                        }
                        default { Send-Json $res @{ ok = $false; message = 'Unknown action.' } }
                    }
                }

                # ----- Family Plan -----
                '/api/family-status' { Send-Json $res (Get-FamilyStatus) }

                '/api/family-unlock' {
                    $cfg = Read-JsonFile $familyFile
                    if (-not ($cfg -and $cfg.pinHash)) { $script:familyUnlocked = $true; Send-Json $res @{ ok = $true }; break }
                    Start-Sleep -Milliseconds 400
                    if ((Get-PinHash ([string]$body.pin) $cfg.pinSalt) -eq $cfg.pinHash) { $script:familyUnlocked = $true; Send-Json $res @{ ok = $true } }
                    else { Send-Json $res @{ ok = $false; message = 'Wrong PIN.' } }
                }

                '/api/family-lock' { $script:familyUnlocked = $false; Send-Json $res @{ ok = $true } }

                '/api/family-pin' {
                    $cfg = Read-JsonFile $familyFile
                    $hasPin = [bool]($cfg -and $cfg.pinHash)
                    if ($hasPin -and -not $script:familyUnlocked) { Send-Json $res @{ ok = $false; message = 'Unlock first.' }; break }
                    $pin = [string]$body.pin
                    if ($pin -notmatch '^\d{4,8}$') { Send-Json $res @{ ok = $false; message = 'Use 4 to 8 numbers.' }; break }
                    $salt = New-Object byte[] 16
                    (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($salt)
                    $saltB64 = [Convert]::ToBase64String($salt)
                    $obj = [ordered]@{}
                    if ($cfg) { foreach ($p in $cfg.PSObject.Properties) { $obj[$p.Name] = $p.Value } }
                    $obj['pinSalt'] = $saltB64
                    $obj['pinHash'] = Get-PinHash $pin $saltB64
                    Write-JsonFile $familyFile $obj
                    $script:familyUnlocked = $true
                    Send-Json $res @{ ok = $true; message = 'Parent PIN saved.' }
                }

                '/api/family-save' {
                    $cfg = Read-JsonFile $familyFile
                    if ($cfg -and $cfg.pinHash -and -not $script:familyUnlocked) { Send-Json $res @{ ok = $false; message = 'Enter the parent PIN first.' }; break }
                    Save-FamilySettings $body.settings
                    Send-Json $res @{ ok = $true; message = 'Family settings saved to the USB.' }
                }

                '/api/family-apply' {
                    $cfg = Read-JsonFile $familyFile
                    if ($cfg -and $cfg.pinHash -and -not $script:familyUnlocked) { Send-Json $res @{ ok = $false; message = 'Enter the parent PIN first.' }; break }
                    Save-FamilySettings $body.settings
                    Send-Json $res (Start-Elevated ([string]$body.script) 'PC Security Toolkit Family Plan.ps1' 'Family Plan')
                }

                '/api/family-remove' {
                    $cfg = Read-JsonFile $familyFile
                    if ($cfg -and $cfg.pinHash -and -not $script:familyUnlocked) { Send-Json $res @{ ok = $false; message = 'Enter the parent PIN first.' }; break }
                    Send-Json $res (Start-Recovery 'RemoveFamily')
                }

                # ----- Recovery Mode -----
                '/api/recovery-list' {
                    $items = @()
                    if (Test-Path -LiteralPath $backupDir) {
                        foreach ($f in @(Get-ChildItem -LiteralPath $backupDir -Filter '*.json' | Sort-Object Name -Descending | Select-Object -First 40)) {
                            $j = Read-JsonFile $f.FullName
                            if ($j -and $j.Format -eq 'PC Security Toolkit snapshot') {
                                $items += @{ file = $f.Name; label = $j.Label; created = $j.Created; elevated = [bool]$j.Elevated; sizeKB = [math]::Round($f.Length / 1KB) }
                            }
                        }
                    }
                    Send-Json $res @{ snapshots = $items; computer = $env:COMPUTERNAME; folder = "Backups\$env:COMPUTERNAME" }
                }

                '/api/recovery-snapshot' {
                    $label = ([string]$body.label -replace '[^A-Za-z0-9 \-\.\(\)]', '').Trim()
                    if (-not $label) { $label = 'Manual snapshot' }
                    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recovery -Mode Snapshot -Label $label -Quiet
                    $ok = ($out -and (Test-Path -LiteralPath ([string]($out | Select-Object -Last 1))))
                    Send-Json $res @{ ok = $ok; message = $(if ($ok) { "Snapshot saved: $label" } else { 'Snapshot failed.' }) }
                }

                '/api/recovery-preview' {
                    $file = [string]$body.file
                    $full = Join-Path $backupDir $file
                    if ($file -notmatch '^[^\\/:*?"<>|]+\.json$' -or -not (Test-Path -LiteralPath $full)) { Send-Json $res @{ ok = $false; output = 'Snapshot not found.' }; break }
                    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recovery -Mode Restore -DryRun -SnapshotPath $full 2>&1
                    Send-Json $res @{ ok = $true; output = (($out | ForEach-Object { "$_" }) -join "`n") }
                }

                '/api/recovery-action' {
                    $action = [string]$body.action
                    $allowed = @('Restore', 'Defaults', 'RemoveFamily', 'RestorePoint', 'SystemRestore', 'Repair', 'NetReset', 'HostsReset', 'NetOff', 'NetOn', 'WinRE', 'SafeOn', 'SafeOff', 'Menu')
                    if ($action -notin $allowed) { Send-Json $res @{ ok = $false; message = 'Unknown recovery action.' }; break }
                    $snapPath = ''
                    if ($action -eq 'Restore') {
                        $file = [string]$body.file
                        $snapPath = Join-Path $backupDir $file
                        if ($file -notmatch '^[^\\/:*?"<>|]+\.json$' -or -not (Test-Path -LiteralPath $snapPath)) { Send-Json $res @{ ok = $false; message = 'Snapshot not found.' }; break }
                    }
                    Send-Json $res (Start-Recovery $action $snapPath)
                }

                '/api/shutdown' {
                    Send-Json $res @{ ok = $true; message = "Server shutting down cleanly." }
                    $listener.Stop()
                }

                default { Send-Json $res @{ ok = $false; message = 'Not found.' } 404 }
            }
        } catch {
            Write-Log 'ERROR' "$path failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
            try { Send-Json $res @{ ok = $false; message = "Server error: $($_.Exception.Message)" } 500 } catch {}
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
