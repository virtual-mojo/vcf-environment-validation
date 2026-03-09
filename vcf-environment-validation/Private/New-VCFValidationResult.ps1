<#
.SYNOPSIS
    Creates a standardised validation result object.

.DESCRIPTION
    Private factory function that all Public validation functions should use
    to return consistent result objects. Keeps result shape uniform across the
    entire module so that New-VCFValidationReport can process them reliably.

.PARAMETER TestName
    Short human-readable name for the check (e.g. 'ESXi SSH Reachability').

.PARAMETER Target
    The IP, FQDN, or resource that was tested.

.PARAMETER Status
    Pass | Fail | Warn | Skip

.PARAMETER Message
    Detail message explaining the result.

.PARAMETER Category
    Logical grouping: Network | Host | Workbook | DNS | NTP | General

.PARAMETER Remediation
    Optional guidance on how to fix a Fail or Warn result.

.EXAMPLE
    New-VCFValidationResult -TestName 'Ping ESXi Host' -Target '10.0.0.10' `
        -Status 'Pass' -Message 'Host responded in 2 ms' -Category 'Network'
#>
function New-VCFValidationResult {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$TestName,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [ValidateSet('Pass','Fail','Warn','Skip')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Network','Host','Workbook','DNS','NTP','General')]
        [string]$Category = 'General',

        [string]$Remediation = ''
    )

    return [PSCustomObject]@{
        PSTypeName   = 'VCF-Environment-Validation.ValidationResult'
        Timestamp    = (Get-Date -Format 'o')   # ISO 8601
        TestName     = $TestName
        Target       = $Target
        Status       = $Status
        Category     = $Category
        Message      = $Message
        Remediation  = $Remediation
    }
}
