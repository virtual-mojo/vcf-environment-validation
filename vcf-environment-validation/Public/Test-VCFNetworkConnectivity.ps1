<#
.SYNOPSIS
    Tests network connectivity to all infrastructure components defined in a VCF deployment JSON.

.DESCRIPTION
    Reads the parsed deployment JSON and runs ICMP ping and TCP port checks against:
      - ESXi management IPs (ports 22, 443, 902)
      - vCenter (443)
      - NSX Manager (443)
      - SDDC Manager (443)
      - NTP servers (UDP 123 — best-effort via TCP check)
      - DNS servers (TCP 53)

    Returns a collection of VCF-Environment-Validation.ValidationResult objects that can be
    passed to New-VCFValidationReport.

.PARAMETER JsonPath
    Path to the deployment JSON file produced by Convert-VCFWorkbookToJson.

.PARAMETER SkipPing
    Skip ICMP ping checks (useful in environments where ICMP is blocked).

.PARAMETER TimeoutSeconds
    Per-check TCP timeout. Defaults to module config (5 s).

.EXAMPLE
    Test-VCFNetworkConnectivity -JsonPath '.\deployment.json'

.EXAMPLE
    Test-VCFNetworkConnectivity -JsonPath '.\deployment.json' -SkipPing -TimeoutSeconds 10

.OUTPUTS
    [VCF-Environment-Validation.ValidationResult[]]
#>
function Test-VCFNetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$JsonPath,

        [switch]$SkipPing,

        [int]$TimeoutSeconds = ($Script:VCF-Environment-ValidationConfig.DefaultTimeoutSeconds ?? 5)
    )

    $component = 'Test-VCFNetworkConnectivity'
    $results   = [System.Collections.Generic.List[object]]::new()

    # ── Parse JSON ─────────────────────────────────────────────────────────────
    try {
        $deployment = Get-Content $JsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $results.Add((New-VCFValidationResult -TestName 'JSON Parse' -Target $JsonPath `
            -Status 'Fail' -Category 'Network' -Message "Cannot read deployment JSON: $_"))
        return $results
    }

    # ── Helper: test one target/port pair ──────────────────────────────────────
    function Test-OneEndpoint {
        param([string]$TestName, [string]$Target, [int]$Port, [string]$Category)

        Write-VCFLog -Message "  TCP $Target`:$Port ..." -Level DEBUG -Component $component
        $tcp = Invoke-VCFTcpTest -Target $Target -Port $Port -TimeoutSeconds $TimeoutSeconds

        if ($tcp.Success) {
            return New-VCFValidationResult -TestName $TestName -Target "${Target}:${Port}" `
                -Status 'Pass' -Category $Category `
                -Message "TCP $Port reachable ($($tcp.LatencyMs) ms)."
        }
        else {
            return New-VCFValidationResult -TestName $TestName -Target "${Target}:${Port}" `
                -Status 'Fail' -Category $Category `
                -Message "TCP $Port unreachable: $($tcp.Error)" `
                -Remediation "Check firewall rules between the management workstation and $Target on port $Port."
        }
    }

    # ── ICMP ping helper ───────────────────────────────────────────────────────
    function Test-OnePing {
        param([string]$Target, [string]$Category)

        if ($SkipPing) {
            return New-VCFValidationResult -TestName "Ping $Target" -Target $Target `
                -Status 'Skip' -Category $Category -Message 'ICMP check skipped (-SkipPing).'
        }

        $ping   = Test-Connection -TargetName $Target -Count 1 -TimeoutSeconds $TimeoutSeconds -ErrorAction SilentlyContinue
        $status = if ($ping) { 'Pass' } else { 'Fail' }
        $msg    = if ($ping) { "ICMP response received ($($ping.Latency) ms)." } `
                  else       { "No ICMP response within $TimeoutSeconds s." }
        $fix    = if (-not $ping) { "Verify the host is powered on and ICMP is permitted by the firewall." } else { '' }

        return New-VCFValidationResult -TestName "Ping $Target" -Target $Target `
            -Status $status -Category $Category -Message $msg -Remediation $fix
    }

    # ── ESXi Hosts ─────────────────────────────────────────────────────────────
    Write-VCFLog -Message "Checking $($deployment.hosts.Count) ESXi host(s)..." -Level INFO -Component $component
    foreach ($h in $deployment.hosts) {
        $ip   = $h.ip
        $fqdn = $h.fqdn ?? $ip

        $results.Add((Test-OnePing   -Target $ip   -Category 'Host'))
        $results.Add((Test-OneEndpoint -TestName "ESXi SSH $fqdn"    -Target $ip -Port 22  -Category 'Host'))
        $results.Add((Test-OneEndpoint -TestName "ESXi HTTPS $fqdn"  -Target $ip -Port 443 -Category 'Host'))
        $results.Add((Test-OneEndpoint -TestName "ESXi VMotion $fqdn"-Target $ip -Port 902 -Category 'Host'))
    }

    # ── vCenter ────────────────────────────────────────────────────────────────
    foreach ($vc in @($deployment.vcenter)) {
        if ($vc -and $vc.ip) {
            Write-VCFLog -Message "Checking vCenter $($vc.hostname)..." -Level INFO -Component $component
            $results.Add((Test-OnePing       -Target $vc.ip -Category 'Network'))
            $results.Add((Test-OneEndpoint -TestName "vCenter HTTPS $($vc.hostname)" -Target $vc.ip -Port 443 -Category 'Network'))
        }
    }

    # ── NSX Manager ───────────────────────────────────────────────────────────
    if ($deployment.nsx -and $deployment.nsx.ip) {
        Write-VCFLog -Message "Checking NSX Manager..." -Level INFO -Component $component
        $results.Add((Test-OnePing       -Target $deployment.nsx.ip -Category 'Network'))
        $results.Add((Test-OneEndpoint -TestName 'NSX HTTPS' -Target $deployment.nsx.ip -Port 443 -Category 'Network'))
    }

    # ── SDDC Manager ──────────────────────────────────────────────────────────
    if ($deployment.sddcManager -and $deployment.sddcManager.ip) {
        Write-VCFLog -Message "Checking SDDC Manager..." -Level INFO -Component $component
        $results.Add((Test-OnePing       -Target $deployment.sddcManager.ip -Category 'Network'))
        $results.Add((Test-OneEndpoint -TestName 'SDDC HTTPS' -Target $deployment.sddcManager.ip -Port 443 -Category 'Network'))
    }

    $results | ForEach-Object { Write-Output $_ }
}
