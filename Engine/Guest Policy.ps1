# Pure request policy. This file must not read or change host configuration.
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
