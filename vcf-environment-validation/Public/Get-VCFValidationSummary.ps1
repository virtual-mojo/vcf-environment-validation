<#
.SYNOPSIS
    Displays a concise console summary of VCF-Environment-Validation results.

.DESCRIPTION
    Accepts an array of VCF-Environment-Validation.ValidationResult objects and prints
    a colour-coded summary table to the host, grouped by category. Useful
    for quick eyeballing without generating a full HTML report.

.PARAMETER Results
    ValidationResult objects. Accepts pipeline input.

.PARAMETER FailOnly
    When specified, only displays Fail and Warn results.

.EXAMPLE
    $r = Test-VCFNetworkConnectivity -JsonPath '.\deployment.json'
    Get-VCFValidationSummary -Results $r

.EXAMPLE
    # Aggregate all checks and view failures only
    $all = @()
    $all += Test-VCFWorkbook -WorkbookPath '.\wb.xlsx'
    $all += Test-VCFJson     -JsonPath     '.\deployment.json'
    $all += Test-VCFNetworkConnectivity -JsonPath '.\deployment.json'
    $all += Test-VCFDnsResolution       -JsonPath '.\deployment.json'
    Get-VCFValidationSummary -Results $all -FailOnly
#>
function Get-VCFValidationSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$Results,

        [switch]$FailOnly
    )

    begin { $all = [System.Collections.Generic.List[object]]::new() }

    process { foreach ($r in $Results) { $all.Add($r) } }

    end {
        $pass  = ($all | Where-Object Status -eq 'Pass').Count
        $fail  = ($all | Where-Object Status -eq 'Fail').Count
        $warn  = ($all | Where-Object Status -eq 'Warn').Count
        $skip  = ($all | Where-Object Status -eq 'Skip').Count

        $overallColor = if ($fail -gt 0) { 'Red' } elseif ($warn -gt 0) { 'Yellow' } else { 'Green' }
        $overallText  = if ($fail -gt 0) { 'FAIL ❌' } elseif ($warn -gt 0) { 'WARN ⚠️' } else { 'PASS ✅' }

        Write-Host ""
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
        Write-Host "  VCF Validation Summary" -ForegroundColor DarkCyan
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
        Write-Host "  Overall : " -NoNewline; Write-Host $overallText -ForegroundColor $overallColor
        Write-Host "  Pass    : $pass" -ForegroundColor Green
        Write-Host "  Fail    : $fail" -ForegroundColor $(if ($fail) { 'Red' } else { 'Gray' })
        Write-Host "  Warn    : $warn" -ForegroundColor $(if ($warn) { 'Yellow' } else { 'Gray' })
        Write-Host "  Skip    : $skip" -ForegroundColor Gray
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
        Write-Host ""

        $filtered = if ($FailOnly) { $all | Where-Object { $_.Status -in 'Fail','Warn' } } else { $all }

        foreach ($cat in ($filtered.Category | Sort-Object -Unique)) {
            Write-Host "  [$cat]" -ForegroundColor DarkCyan
            $filtered | Where-Object Category -eq $cat | ForEach-Object {
                $color = switch ($_.Status) {
                    'Pass' { 'Green' } 'Fail' { 'Red' } 'Warn' { 'Yellow' } default { 'Gray' }
                }
                $icon  = switch ($_.Status) {
                    'Pass' { '✅' } 'Fail' { '❌' } 'Warn' { '⚠️' } default { '⏭️' }
                }
                Write-Host "    $icon [$($_.Status)] $($_.TestName) — $($_.Target)" -ForegroundColor $color
                if ($_.Remediation) {
                    Write-Host "         🔧 $($_.Remediation)" -ForegroundColor DarkYellow
                }
            }
            Write-Host ""
        }
    }
}
