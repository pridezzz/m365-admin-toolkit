<#
.SYNOPSIS
    Audits MFA enrollment status across all enabled Entra ID users.

.DESCRIPTION
    For each enabled user, lists registered authentication methods and flags
    accounts with no strong MFA method registered. Useful for security posture
    reviews and pre-deployment checks before tightening Conditional Access.

.PARAMETER OnlyWithoutMfa
    If specified, returns only users who lack a strong MFA method.

.PARAMETER ExportCsv
    If specified, exports results to mfa-status-YYYY-MM-DD.csv in the current folder.

.EXAMPLE
    .\Get-MFAStatus.ps1 -OnlyWithoutMfa -ExportCsv

.NOTES
    Requires: Microsoft.Graph module, Connect-MgGraph with
              User.Read.All and UserAuthenticationMethod.Read.All
    Author:   Lovro Lulić
#>

[CmdletBinding()]
param(
    [switch]$OnlyWithoutMfa,
    [switch]$ExportCsv
)

$context = Get-MgContext
if (-not $context) {
    Write-Host "Not connected to Microsoft Graph. Run Connect-MgGraph first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Auditing MFA status (this can take a while in large tenants)..." -ForegroundColor Cyan

# Methods that count as "strong" MFA
$strongMethodTypes = @(
    "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"
    "#microsoft.graph.fido2AuthenticationMethod"
    "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod"
    "#microsoft.graph.softwareOathAuthenticationMethod"
    "#microsoft.graph.phoneAuthenticationMethod"
)

$users = Get-MgUser -All -Filter "accountEnabled eq true" `
    -Property "Id,DisplayName,UserPrincipalName"

$report = foreach ($user in $users) {
    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction Stop

        $methodTypes = $methods | ForEach-Object { $_.AdditionalProperties['@odata.type'] }
        $hasStrongMfa = ($methodTypes | Where-Object { $_ -in $strongMethodTypes }).Count -gt 0

        $methodSummary = ($methodTypes |
            ForEach-Object { $_ -replace '#microsoft.graph.', '' -replace 'AuthenticationMethod', '' }
        ) -join ', '

        [PSCustomObject]@{
            DisplayName       = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            HasStrongMfa      = $hasStrongMfa
            Methods           = if ($methodSummary) { $methodSummary } else { "None" }
        }
    }
    catch {
        Write-Warning "Could not read methods for $($user.UserPrincipalName): $_"
    }
}

if ($OnlyWithoutMfa) {
    $report = $report | Where-Object { -not $_.HasStrongMfa }
}

$report | Sort-Object HasStrongMfa, DisplayName | Format-Table -AutoSize

$noMfaCount = ($report | Where-Object { -not $_.HasStrongMfa }).Count
Write-Host "`n$noMfaCount user(s) without strong MFA." -ForegroundColor $(if ($noMfaCount -gt 0) { "Yellow" } else { "Green" })

if ($ExportCsv) {
    $filename = "mfa-status-$(Get-Date -Format 'yyyy-MM-dd').csv"
    $report | Export-Csv -Path $filename -NoTypeInformation -Encoding UTF8
    Write-Host "Exported to $filename" -ForegroundColor Green
}