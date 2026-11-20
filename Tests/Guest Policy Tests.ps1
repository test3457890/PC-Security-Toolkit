$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
# Parse all PowerShell sources without executing OS-changing code.
Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' | ForEach-Object {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw "Parse errors in $($_.FullName): $($errors -join '; ')" }
}
. (Join-Path $root 'Engine/Guest Policy.ps1')
if ((ConvertFrom-GuestJson '{"authorized":true}').authorized -ne $true) { throw 'Valid object must parse.' }
foreach ($invalid in @('[]', '[{"authorized":true}]', 'null', 'true', '42', '"text"', '{broken')) {
    $rejected = $false
    try { ConvertFrom-GuestJson $invalid | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Non-object or malformed JSON must be rejected.' }
}
if ($null -ne (Get-ObservedFlag $null)) { throw 'Missing flag must be unknown.' }
if ((Get-ObservedFlag 0) -ne $false -or (Get-ObservedFlag 1) -ne $true) { throw 'Observed flags do not match.' }
if ($null -ne (Get-ObservedFirewall @())) { throw 'Unreadable firewall must be unknown.' }
$profiles = @('Domain','Private','Public') | ForEach-Object { [pscustomobject]@{ Name = $_; Enabled = 'True' } }
if ((Get-ObservedFirewall $profiles) -ne $true) { throw 'All enabled profiles expected true.' }
$profiles[0].Enabled = 'False'
if ((Get-ObservedFirewall $profiles) -ne $false) { throw 'Disabled profile expected false.' }
if ($null -ne (Get-ObservedFirewall @($profiles[0]))) { throw 'Partial profile query must be unknown.' }
$profiles[0].Enabled = 'NotConfigured'
if ($null -ne (Get-ObservedFirewall $profiles)) { throw 'Unrecognized state must be unknown.' }
function Assert-Decision($path, $method, $consent, $expected) {
    $actual = Get-GuestRequestDecision -Path $path -Method $method -Consented $consent
    if ($actual.Status -ne $expected) { throw "$method $path returned $($actual.Status), expected $expected" }
}
$source = Get-Content -LiteralPath (Join-Path $root 'Engine/Toolkit Server.ps1') -Raw
$routes = [regex]::Matches($source, "'(/api/[^']+)'\s*\{") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$allowed = @('/api/settings','/api/session','/api/consent','/api/scan','/api/cache-sizes','/api/shutdown')
foreach ($route in $routes) {
    if ($route -in $allowed) { continue }
    foreach ($consent in @($true, $false)) {
        foreach ($method in @('GET','POST','PUT','DELETE')) { Assert-Decision $route $method $consent 403 }
    }
}
Assert-Decision '/api/scan' 'GET' $false 409
Assert-Decision '/api/scan' 'GET' $true 200
Assert-Decision '/api/cache-sizes' 'GET' $false 409
Assert-Decision '/api/cache-sizes' 'GET' $true 200
Assert-Decision '/api/scan' 'POST' $true 405
Assert-Decision '/api/shutdown' 'GET' $true 405
Assert-Decision '/api/shutdown' 'POST' $false 200
Assert-Decision '/api/settings' 'POST' $true 405
Assert-Decision '/api/not-a-route' 'GET' $true 403
# Check integration placement in the server without starting its listener.
$gate = $source.IndexOf('$decision = Get-GuestRequestDecision')
$dispatch = $source.IndexOf('switch ($path)')
if ($gate -lt 0 -or $gate -gt $dispatch) { throw 'Guest policy must run before dispatch.' }
if ($source -notmatch 'if \(-not \$decision.Allowed\).*continue') { throw 'Denied requests must exit before dispatch.' }
Write-Output 'PASS: PowerShell parsing, all legacy route denials, consent and method policy. No OS actions executed.'
