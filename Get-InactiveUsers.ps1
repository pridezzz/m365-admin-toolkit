<#
.SYNOPSIS
    Finds Entra ID users who haven't signed in for a specified number of days.

.DESCRIPTION
    Queries Microsoft Graph for all enabled users and reports those whose last
    interactive sign-in is older than the threshold. Useful for license reclaim
    and account hygiene audits.

.PARAMETER Days
    Inactivity threshold in days. Defaults to 30.

.PARAMETER ExportCsv
    If specified, exports results to inactive-users-YYYY-MM-DD.csv in the current folder.

.EXAMPLE
    .\Get-InactiveUsers.ps1 -Days 60 -ExportCsv

.NOTES
    Requires: Microsoft.Graph module, Connect-MgGraph with User.Read.All and AuditLog.Read.All
    Author:   Lovro Lulić
#>

[CmdletBinding()]
param(
    [int]$Days = 30,
    [switch]$ExportCsv
)

# Verify Graph connection
$context = Get-MgContext
if (-not $context) {
    Write-Host "Not connected to Microsoft Graph. Run Connect-MgGraph first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Scanning for users inactive for $Days+ days..." -ForegroundColor Cyan

$threshold = (Get-Date).AddDays(-$Days)

# Pull all enabled users with sign-in activity
$users = Get-MgUser -All -Filter "accountEnabled eq true" `
    -Property "Id,DisplayName,UserPrincipalName,AccountEnabled,SignInActivity,CreatedDateTime"

$inactive = foreach ($user in $users) {
    $lastSignIn = $user.SignInActivity.LastSignInDateTime

    # Skip users who have signed in recently
    if ($lastSignIn -and $lastSignIn -gt $threshold) { continue }

    [PSCustomObject]@{
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        LastSignIn        = if ($lastSignIn) { $lastSignIn } else { "Never" }
        DaysSinceSignIn   = if ($lastSignIn) { [math]::Round(((Get-Date) - $lastSignIn).TotalDays) } else { "N/A" }
        AccountCreated    = $user.CreatedDateTime
    }
}

if (-not $inactive) {
    Write-Host "No inactive users found." -ForegroundColor Green
    exit 0
}

$inactive | Sort-Object DaysSinceSignIn -Descending | Format-Table -AutoSize

Write-Host "`nFound $($inactive.Count) inactive user(s)." -ForegroundColor Yellow

if ($ExportCsv) {
    $filename = "inactive-users-$(Get-Date -Format 'yyyy-MM-dd').csv"
    $inactive | Export-Csv -Path $filename -NoTypeInformation -Encoding UTF8
    Write-Host "Exported to $filename" -ForegroundColor Green
}