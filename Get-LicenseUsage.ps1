<#
.SYNOPSIS
    Reports on Microsoft 365 license assignment across the tenant.

.DESCRIPTION
    Queries Microsoft Graph for all subscribed SKUs and shows total, assigned,
    and available counts. Highlights underused licenses so you can spot waste
    before renewal.

.PARAMETER ExportCsv
    If specified, exports results to license-usage-YYYY-MM-DD.csv in the current folder.

.EXAMPLE
    .\Get-LicenseUsage.ps1 -ExportCsv

.NOTES
    Requires: Microsoft.Graph module, Connect-MgGraph with Directory.Read.All
    Author:   Lovro Lulić
#>

[CmdletBinding()]
param(
    [switch]$ExportCsv
)

$context = Get-MgContext
if (-not $context) {
    Write-Host "Not connected to Microsoft Graph. Run Connect-MgGraph first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Fetching license inventory..." -ForegroundColor Cyan

$skus = Get-MgSubscribedSku -All

$report = foreach ($sku in $skus) {
    $total     = $sku.PrepaidUnits.Enabled
    $assigned  = $sku.ConsumedUnits
    $available = $total - $assigned
    $usagePct  = if ($total -gt 0) { [math]::Round(($assigned / $total) * 100, 1) } else { 0 }

    [PSCustomObject]@{
        SkuPartNumber = $sku.SkuPartNumber
        Total         = $total
        Assigned      = $assigned
        Available     = $available
        UsagePercent  = $usagePct
    }
}

$report | Sort-Object UsagePercent | Format-Table -AutoSize

# Highlight underused licenses
$underused = $report | Where-Object { $_.Available -gt 0 -and $_.Total -gt 0 }
if ($underused) {
    Write-Host "`nLicenses with unused seats (potential cost savings):" -ForegroundColor Yellow
    $underused | Format-Table SkuPartNumber, Available, UsagePercent -AutoSize
}

if ($ExportCsv) {
    $filename = "license-usage-$(Get-Date -Format 'yyyy-MM-dd').csv"
    $report | Export-Csv -Path $filename -NoTypeInformation -Encoding UTF8
    Write-Host "Exported to $filename" -ForegroundColor Green
}