# VCF-Environment-Validation

> PowerShell module for pre-installation validation of VMware Cloud Foundation (VCF) environments.

Run this module **before** you deploy the VCF installer appliance to catch misconfigurations
early — workbook structure, JSON schema, DNS, network connectivity, and more.

---

## Requirements

| Dependency | Version | Notes |
|---|---|---|
| PowerShell | 7.0+ | Required (cross-platform) |
| ImportExcel | 7.0+ | Required for workbook/xlsx functions |
| Pester | 5.0+ | Required to run unit tests |

```powershell
# Install optional/required dependencies
Install-Module ImportExcel -Scope CurrentUser
Install-Module Pester      -Scope CurrentUser -Force -SkipPublisherCheck
```

---

## Installation

```powershell
# Clone or download this repository, then import
Import-Module .\VCF-Environment-Validation\VCF-Environment-Validation.psd1

# Or copy to a PSModulePath folder for automatic discovery
Copy-Item -Recurse .\VCF-Environment-Validation "$HOME\Documents\PowerShell\Modules\VCF-Environment-Validation"
Import-Module VCF-Environment-Validation
```

---

## Quick Start

```powershell
Import-Module .\VCF-Environment-Validation\VCF-Environment-Validation.psd1

# 1. Validate the Excel workbook
$workbookResults = Test-VCFWorkbook -WorkbookPath '.\deployment-params.xlsx'

# 2. Convert workbook to JSON
Convert-VCFWorkbookToJson -WorkbookPath '.\deployment-params.xlsx' `
                          -OutputPath   '.\deployment.json' -Force

# 3. Validate JSON structure
$jsonResults = Test-VCFJson -JsonPath '.\deployment.json'

# 4. Test network connectivity to all components
$netResults = Test-VCFNetworkConnectivity -JsonPath '.\deployment.json'

# 5. Test DNS forward + reverse for all FQDNs
$dnsResults = Test-VCFDnsResolution -JsonPath '.\deployment.json'

# 6. View console summary
$all = $workbookResults + $jsonResults + $netResults + $dnsResults
Get-VCFValidationSummary -Results $all

# 7. Generate HTML report
New-VCFValidationReport -Results $all -OutputPath '.\vcf-validation.html' -Open
```

---

## Module Structure

```
VCF-Environment-Validation/
├── VCF-Environment-Validation.psd1          # Module manifest
├── VCF-Environment-Validation.psm1          # Root loader — auto-discovers Public & Private functions
│
├── Public/                    # ✅ Exported functions (available to users)
│   ├── Test-VCFWorkbook.ps1
│   ├── Convert-VCFWorkbookToJson.ps1
│   ├── Test-VCFJson.ps1
│   ├── Test-VCFNetworkConnectivity.ps1
│   ├── Test-VCFDnsResolution.ps1
│   ├── Test-VCFNtpReachability.ps1       ← add your own
│   ├── Test-VCFHostConnectivity.ps1      ← add your own
│   ├── New-VCFValidationReport.ps1
│   └── Get-VCFValidationSummary.ps1
│
├── Private/                   # 🔒 Internal helpers (NOT exported)
│   ├── Write-VCFLog.ps1
│   ├── New-VCFValidationResult.ps1
│   └── Invoke-VCFTcpTest.ps1
│
└── Tests/
    └── VCF-Environment-Validation.Tests.ps1  # Pester v5 unit tests
```

### Adding a New Function

**Public (exported):**
```powershell
# Create Public\Test-VCFSomething.ps1 with this signature:
function Test-VCFSomething {
    [CmdletBinding()]
    param(...)

    # Use private helpers freely:
    Write-VCFLog -Message "..." -Level INFO -Component 'Test-VCFSomething'

    New-VCFValidationResult -TestName '...' -Target '...' `
        -Status 'Pass' -Category 'Network' -Message '...'
}
```
The module loader picks it up automatically — no manifest edits needed for loading,
but update `FunctionsToExport` in `VCF-Environment-Validation.psd1` to keep the manifest accurate.

**Private (internal only):**
Drop a `.ps1` into `Private\`. Same auto-discovery applies; the function is never exported.

---

## Validation Result Schema

All `Test-VCF*` functions return `[PSCustomObject]` with type tag `VCF-Environment-Validation.ValidationResult`:

| Property | Type | Values |
|---|---|---|
| Timestamp | string | ISO 8601 |
| TestName | string | Human-readable check name |
| Target | string | IP, FQDN, or path being tested |
| Status | string | `Pass` / `Fail` / `Warn` / `Skip` |
| Category | string | `Network` / `Host` / `Workbook` / `DNS` / `NTP` / `General` |
| Message | string | Detail |
| Remediation | string | How to fix (populated on Fail/Warn) |

---

## Running Tests

```powershell
Invoke-Pester -Path .\Tests\ -Output Detailed
```

---

## Roadmap / Planned Functions

| Function | Description |
|---|---|
| `Test-VCFNtpReachability` | Verify NTP servers are reachable (UDP 123) |
| `Test-VCFHostConnectivity` | SSH into ESXi hosts and run preflight checks |
| `Test-VCFEsxiVersion` | Confirm ESXi build numbers meet VCF minimum requirements |
| `Test-VCFVlanConfig` | Validate VLAN tags against physical switch config |
| `Test-VCFPasswordPolicy` | Validate passwords meet VCF complexity requirements |
| `Invoke-VCFFullPrecheck` | Run all checks in one call and produce a report |
