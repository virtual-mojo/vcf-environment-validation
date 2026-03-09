<#
.SYNOPSIS
    Generates a formatted HTML or text validation report from VCF-Environment-Validation results.

.DESCRIPTION
    Accepts an array of VCF-Environment-Validation.ValidationResult objects (from any of the
    Test-VCF* functions) and produces a colour-coded HTML report or a plain-text
    summary. Pass results from multiple validation runs by combining arrays.

.PARAMETER Results
    One or more ValidationResult objects. Accepts pipeline input.

.PARAMETER OutputPath
    Optional file path for the report. Extension determines format:
      .html → HTML report (default)
      .txt  → Plain-text report
    If omitted, the HTML report is written to the current directory.

.PARAMETER Title
    Report title string. Defaults to 'VCF Pre-Installation Validation Report'.

.PARAMETER Open
    Open the report in the default browser (HTML) or text editor after generation.

.EXAMPLE
    $results = Test-VCFWorkbook -WorkbookPath '.\wb.xlsx'
    $results += Test-VCFJson -JsonPath '.\deployment.json'
    $results += Test-VCFNetworkConnectivity -JsonPath '.\deployment.json'
    New-VCFValidationReport -Results $results -OutputPath '.\vcf-validation.html' -Open

.OUTPUTS
    [System.IO.FileInfo]
#>
function New-VCFValidationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$Results,

        [string]$OutputPath,

        [string]$Title = 'VCF Pre-Installation Validation Report',

        [switch]$Open
    )

    begin {
        $allResults = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($r in $Results) { $allResults.Add($r) }
    }

    end {
        # Default output path
        if (-not $OutputPath) {
            $OutputPath = Join-Path (Get-Location) ("vcf-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').html")
        }

        $pass  = ($allResults | Where-Object Status -eq 'Pass').Count
        $fail  = ($allResults | Where-Object Status -eq 'Fail').Count
        $warn  = ($allResults | Where-Object Status -eq 'Warn').Count
        $skip  = ($allResults | Where-Object Status -eq 'Skip').Count
        $total = $allResults.Count
        $overall = if ($fail -gt 0) { 'FAIL' } elseif ($warn -gt 0) { 'WARN' } else { 'PASS' }

        # ── Plain-text output ──────────────────────────────────────────────────
        if ([System.IO.Path]::GetExtension($OutputPath) -eq '.txt') {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add("=" * 80)
            $lines.Add($Title.ToUpper())
            $lines.Add("Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
            $lines.Add("Overall   : $overall  |  Pass: $pass  Fail: $fail  Warn: $warn  Skip: $skip  Total: $total")
            $lines.Add("=" * 80)

            foreach ($cat in ($allResults.Category | Sort-Object -Unique)) {
                $lines.Add("")
                $lines.Add("[$cat]")
                $lines.Add("-" * 40)
                $allResults | Where-Object Category -eq $cat | ForEach-Object {
                    $icon = switch ($_.Status) { 'Pass'{'[PASS]'} 'Fail'{'[FAIL]'} 'Warn'{'[WARN]'} default{'[SKIP]'} }
                    $lines.Add("$icon $($_.TestName) — $($_.Target)")
                    $lines.Add("       $($_.Message)")
                    if ($_.Remediation) { $lines.Add("       FIX: $($_.Remediation)") }
                }
            }

            $lines | Set-Content -Path $OutputPath -Encoding UTF8
        }
        else {
            # ── HTML output ────────────────────────────────────────────────────
            $overallColor = switch ($overall) { 'PASS'{'#2ecc71'} 'WARN'{'#f39c12'} default{'#e74c3c'} }

            $rowsHtml = $allResults | ForEach-Object {
                $bg = switch ($_.Status) {
                    'Pass' { '#eafaf1' } 'Fail' { '#fdecea' } 'Warn' { '#fef9e7' } default { '#f8f9fa' }
                }
                $icon = switch ($_.Status) {
                    'Pass' { '✅' } 'Fail' { '❌' } 'Warn' { '⚠️' } default { '⏭️' }
                }
                $rem = if ($_.Remediation) { "<br><small style='color:#888'>🔧 $($_.Remediation)</small>" } else { '' }
                "<tr style='background:$bg'>
                    <td>$icon $($_.Status)</td>
                    <td>$($_.Category)</td>
                    <td>$($_.TestName)</td>
                    <td>$($_.Target)</td>
                    <td>$($_.Message)$rem</td>
                </tr>"
            }

            $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>$Title</title>
<style>
  body { font-family: 'Segoe UI', sans-serif; margin: 2rem; background: #f5f6fa; color: #2c3e50; }
  h1   { font-size: 1.6rem; }
  .summary { display:flex; gap:1.5rem; margin: 1rem 0 1.5rem; }
  .badge { padding:.5rem 1.2rem; border-radius:8px; font-weight:bold; font-size:1.1rem; color:#fff; }
  table { border-collapse:collapse; width:100%; background:#fff; border-radius:8px; overflow:hidden; box-shadow:0 1px 4px rgba(0,0,0,.1); }
  th { background:#2c3e50; color:#fff; padding:.6rem 1rem; text-align:left; font-size:.85rem; text-transform:uppercase; }
  td { padding:.55rem 1rem; font-size:.9rem; border-bottom:1px solid #eee; vertical-align:top; }
  tr:last-child td { border-bottom:none; }
  .overall { background:$overallColor; }
</style>
</head>
<body>
<h1>$Title</h1>
<p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<div class="summary">
  <div class="badge overall">Overall: $overall</div>
  <div class="badge" style="background:#2ecc71">Pass: $pass</div>
  <div class="badge" style="background:#e74c3c">Fail: $fail</div>
  <div class="badge" style="background:#f39c12">Warn: $warn</div>
  <div class="badge" style="background:#95a5a6">Skip: $skip</div>
  <div class="badge" style="background:#7f8c8d">Total: $total</div>
</div>
<table>
<thead><tr><th>Status</th><th>Category</th><th>Test</th><th>Target</th><th>Detail</th></tr></thead>
<tbody>
$($rowsHtml -join "`n")
</tbody>
</table>
</body>
</html>
"@
            $html | Set-Content -Path $OutputPath -Encoding UTF8
        }

        Write-VCFLog -Message "Report saved: $OutputPath" -Level SUCCESS -Component 'New-VCFValidationReport'

        if ($Open) {
            Start-Process $OutputPath
        }

        Get-Item $OutputPath
    }
}
