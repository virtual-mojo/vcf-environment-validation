<#
.SYNOPSIS
    Validates forward and reverse DNS resolution for all VCF component FQDNs.

.DESCRIPTION
    For each host, vCenter, NSX Manager, and SDDC Manager entry in the deployment
    JSON, verifies that:
      1. The FQDN resolves to the expected IP (forward lookup).
      2. The IP resolves back to the expected FQDN (reverse/PTR lookup).

    Mismatched forward/reverse DNS is a common cause of VCF installation failures.

.PARAMETER JsonPath
    Path to the deployment JSON file.

.EXAMPLE
    Test-VCFDnsResolution -JsonPath '.\deployment.json'

.OUTPUTS
    [VCF-Environment-Validation.ValidationResult[]]
#>
function Test-VCFDnsResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$JsonPath
    )

    $component = 'Test-VCFDnsResolution'
    $results   = [System.Collections.Generic.List[object]]::new()

    try {
        $deployment = Get-Content $JsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $results.Add((New-VCFValidationResult -TestName 'JSON Parse' -Target $JsonPath `
            -Status 'Fail' -Category 'DNS' -Message "Cannot read JSON: $_"))
        return $results
    }

    # ── Inner helper: forward + reverse ───────────────────────────────────────
    function Test-FqdnIpPair {
        param([string]$Fqdn, [string]$ExpectedIp, [string]$Role)

        # Forward
        try {
            $resolved = [System.Net.Dns]::GetHostAddresses($Fqdn) | Select-Object -ExpandProperty IPAddressToString
            if ($ExpectedIp -in $resolved) {
                $results.Add((New-VCFValidationResult -TestName "DNS Forward: $Fqdn" -Target $Fqdn `
                    -Status 'Pass' -Category 'DNS' -Message "$Fqdn resolves to $ExpectedIp (correct)."))
            }
            else {
                $results.Add((New-VCFValidationResult -TestName "DNS Forward: $Fqdn" -Target $Fqdn `
                    -Status 'Fail' -Category 'DNS' `
                    -Message "$Fqdn resolved to [$($resolved -join ', ')] — expected $ExpectedIp." `
                    -Remediation "Update the A record for $Fqdn to point to $ExpectedIp."))
            }
        }
        catch {
            $results.Add((New-VCFValidationResult -TestName "DNS Forward: $Fqdn" -Target $Fqdn `
                -Status 'Fail' -Category 'DNS' -Message "Forward lookup failed: $_" `
                -Remediation "Create an A record for $Fqdn → $ExpectedIp in your DNS server."))
        }

        # Reverse (PTR)
        try {
            $ptr = [System.Net.Dns]::GetHostEntry($ExpectedIp).HostName
            if ($ptr -ieq $Fqdn) {
                $results.Add((New-VCFValidationResult -TestName "DNS Reverse: $ExpectedIp" -Target $ExpectedIp `
                    -Status 'Pass' -Category 'DNS' -Message "PTR for $ExpectedIp → $ptr (correct)."))
            }
            else {
                $results.Add((New-VCFValidationResult -TestName "DNS Reverse: $ExpectedIp" -Target $ExpectedIp `
                    -Status 'Warn' -Category 'DNS' `
                    -Message "PTR for $ExpectedIp → '$ptr' (expected '$Fqdn')." `
                    -Remediation "Update the PTR record for $ExpectedIp to return $Fqdn."))
            }
        }
        catch {
            $results.Add((New-VCFValidationResult -TestName "DNS Reverse: $ExpectedIp" -Target $ExpectedIp `
                -Status 'Fail' -Category 'DNS' -Message "Reverse lookup failed: $_" `
                -Remediation "Create a PTR record for $ExpectedIp → $Fqdn in your DNS server."))
        }
    }

    # ── Hosts ──────────────────────────────────────────────────────────────────
    foreach ($h in $deployment.hosts) {
        if ($h.fqdn -and $h.ip) {
            Write-VCFLog -Message "DNS check: $($h.fqdn) / $($h.ip)" -Level DEBUG -Component $component
            Test-FqdnIpPair -Fqdn $h.fqdn -ExpectedIp $h.ip -Role 'ESXi Host'
        }
    }

    # ── vCenter ────────────────────────────────────────────────────────────────
    foreach ($vc in @($deployment.vcenter)) {
        if ($vc.hostname -and $vc.ip) {
            Test-FqdnIpPair -Fqdn $vc.hostname -ExpectedIp $vc.ip -Role 'vCenter'
        }
    }

    # ── NSX ────────────────────────────────────────────────────────────────────
    if ($deployment.nsx -and $deployment.nsx.hostname -and $deployment.nsx.ip) {
        Test-FqdnIpPair -Fqdn $deployment.nsx.hostname -ExpectedIp $deployment.nsx.ip -Role 'NSX Manager'
    }

    # ── SDDC Manager ──────────────────────────────────────────────────────────
    if ($deployment.sddcManager -and $deployment.sddcManager.hostname -and $deployment.sddcManager.ip) {
        Test-FqdnIpPair -Fqdn $deployment.sddcManager.hostname -ExpectedIp $deployment.sddcManager.ip -Role 'SDDC Manager'
    }

    $results | ForEach-Object { Write-Output $_ }
}
