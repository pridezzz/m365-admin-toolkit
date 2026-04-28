# M365 Admin Toolkit

A small collection of PowerShell scripts I built for everyday Microsoft 365 administration tasks — the kind of stuff that comes up weekly when you're running M365 for a 30+ person company.

Each script solves a real problem I've run into: license waste, stale accounts, MFA gaps. They're meant to be readable, easy to adapt, and safe to run (read-only by default — they report, they don't modify).

## Scripts

### `Get-InactiveUsers.ps1`

Finds Entra ID users who haven't signed in for X days. Useful for:
- Reclaiming licenses from accounts that were never used
- Identifying offboarded users who slipped through the cracks
- Quarterly account hygiene audits

### `Get-LicenseUsage.ps1`

Reports on Microsoft 365 license assignment across the tenant — total purchased vs. assigned vs. available, broken down by SKU. Useful for:
- Spotting unused licenses before renewal
- Justifying license reallocation to Finance
- Catching SKUs you forgot you were paying for

### `Get-MFAStatus.ps1`

Audits MFA enrollment status across all users. Useful for:
- Security posture reviews
- Identifying accounts that bypassed Conditional Access
- Pre-deployment checks before tightening MFA policies

## Requirements

- PowerShell 7+
- Microsoft Graph PowerShell SDK (`Install-Module Microsoft.Graph -Scope CurrentUser`)
- An Entra ID account with at least `User.Read.All`, `Directory.Read.All`, and `AuditLog.Read.All` permissions

## Usage

```powershell
