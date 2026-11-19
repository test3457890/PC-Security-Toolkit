# Pure request policy. This file must not read or change host configuration.
function ConvertFrom-GuestJson([string]$Text) {
    if (-not $Text) { return [pscustomobject]@{} }
    # PowerShell otherwise unwraps a one-item JSON array during assignment.
    if (-not $Text.TrimStart().StartsWith('{')) { throw 'JSON object required.' }
    $value = ConvertFrom-Json -InputObject $Text -ErrorAction Stop
    if ($value -isnot [System.Management.Automation.PSCustomObject]) { throw 'JSON object required.' }
    return $value
}

function Get-ObservedFlag($Value, $Expected = 1) {
    if ($null -eq $Value) { return $null }
    return ($Value -eq $Expected)
}

function Get-ObservedFirewall($Profiles) {
    # All three Windows profiles must be readable before claiming protection.
    foreach ($name in @('Domain', 'Private', 'Public')) {
        $profile = @($Profiles | Where-Object { $_.Name -eq $name })
        if ($profile.Count -ne 1 -or "$($profile[0].Enabled)" -notin @('True', 'False')) { return $null }
    }
    return (@($Profiles | Where-Object { "$($_.Enabled)" -eq 'False' }).Count -eq 0)
}

function Get-GuestRequestDecision {
    param([string]$Path, [string]$Method, [bool]$Consented)
    $routes = @{
        '/api/settings' = 'GET'
        '/api/session' = 'GET'
        '/api/consent' = 'POST'
        '/api/scan' = 'GET'
        '/api/cache-sizes' = 'GET'
        '/api/shutdown' = 'POST'
    }
    if (-not $routes.ContainsKey($Path)) {
        return @{ Allowed = $false; Status = 403; Code = 'guest_read_only'; Message = 'Scan only. Changes, external tools and persistent data are unavailable in this preview.' }
    }
    if ($Method -cne $routes[$Path]) {
        return @{ Allowed = $false; Status = 405; Code = 'method_not_allowed'; Message = 'Method not allowed.' }
    }
    if ($Path -in @('/api/scan', '/api/cache-sizes') -and -not $Consented) {
        return @{ Allowed = $false; Status = 409; Code = 'consent_required'; Message = 'Choose Scan this PC and confirm permission before collecting system information.' }
    }
    return @{ Allowed = $true; Status = 200 }
}
