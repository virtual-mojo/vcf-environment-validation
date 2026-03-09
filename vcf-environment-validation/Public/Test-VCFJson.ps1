<#
.SYNOPSIS
    Validates a VCF deployment JSON file for required fields and value formats.

.DESCRIPTION
    Parses the JSON file produced by Convert-VCFWorkbookToJson (or hand-authored)
    and checks for the presence of required top-level and nested properties,
    valid IP address formats, non-empty hostnames, and schema version compatibility.

.PARAMETER JsonPath
    Path to the deployment JSON file.

.PARAMETER SchemaVersion
    Expected schemaVersion string in the JSON. Defaults to '1.0'.

.EXAMPLE
    Test-VCFJson -JsonPath '.\deployment.json'

.OUTPUTS
    [VCF-Environment-Validation.ValidationResult[]]
#>
function Test-VCFJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$JsonPath,

        [string]$SchemaVersion = '1.0'
    )

    $component = 'Test-VCFJson'
    $results   = [System.Collections.Generic.List[object]]::new()

    Write-VCFLog -Message "Validating JSON: $JsonPath" -Level INFO -Component $component

    # ── Parse ──────────────────────────────────────────────────────────────────
    try {
        $raw        = Get-Content -Path $JsonPath -Raw -Encoding UTF8
        $deployment = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $results.Add((New-VCFValidationResult -TestName 'JSON Parse' -Target $JsonPath `
            -Status 'Fail' -Category 'Workbook' `
            -Message "JSON parse error: $_" `
            -Remediation 'Validate the file with a JSON linter (e.g. https://jsonlint.com).'))
        return $results
    }

    $results.Add((New-VCFValidationResult -TestName 'JSON Parse' -Target $JsonPath `
        -Status 'Pass' -Category 'Workbook' -Message 'File parsed as valid JSON.'))

    # ── Schema version ─────────────────────────────────────────────────────────
    $actualSchema = $deployment.schemaVersion
    if ($actualSchema -eq $SchemaVersion) {
        $results.Add((New-VCFValidationResult -TestName 'Schema Version' -Target $JsonPath `
            -Status 'Pass' -Category 'Workbook' -Message "Schema version '$actualSchema' matches expected."))
    }
    else {
        $results.Add((New-VCFValidationResult -TestName 'Schema Version' -Target $JsonPath `
            -Status 'Warn' -Category 'Workbook' `
            -Message "Schema version '$actualSchema' does not match expected '$SchemaVersion'." `
            -Remediation 'Re-generate the JSON with the current version of Convert-VCFWorkbookToJson.'))
    }

    # ── Required top-level keys ────────────────────────────────────────────────
    $requiredKeys = @('sddcManager', 'vcenter', 'nsx', 'hosts', 'vsan')
    foreach ($key in $requiredKeys) {
        if ($null -ne $deployment.$key) {
            $results.Add((New-VCFValidationResult -TestName "Key Present: $key" -Target $JsonPath `
                -Status 'Pass' -Category 'Workbook' -Message "Top-level key '$key' is present."))
        }
        else {
            $results.Add((New-VCFValidationResult -TestName "Key Present: $key" -Target $JsonPath `
                -Status 'Fail' -Category 'Workbook' `
                -Message "Required top-level key '$key' is missing or null." `
                -Remediation "Ensure the source workbook sheet for '$key' contains data."))
        }
    }

    # ── Host entries: IP format + FQDN not empty ───────────────────────────────
    $ipRegex = '^(\d{1,3}\.){3}\d{1,3}$'
    $hostIndex = 0
    foreach ($h in $deployment.hosts) {
        $hostIndex++
        $label = "Host[$hostIndex]"

        # FQDN / IP presence
        if ([string]::IsNullOrWhiteSpace($h.fqdn)) {
            $results.Add((New-VCFValidationResult -TestName "$label FQDN" -Target "Host index $hostIndex" `
                -Status 'Fail' -Category 'Workbook' `
                -Message 'Host FQDN is empty.' -Remediation 'Populate the FQDN column in the Hosts and Networks sheet.'))
        }
        else {
            $results.Add((New-VCFValidationResult -TestName "$label FQDN" -Target $h.fqdn `
                -Status 'Pass' -Category 'Workbook' -Message "FQDN is populated: $($h.fqdn)"))
        }

        if ([string]::IsNullOrWhiteSpace($h.ip)) {
            $results.Add((New-VCFValidationResult -TestName "$label IP" -Target ($h.fqdn ?? "Host[$hostIndex]") `
                -Status 'Fail' -Category 'Workbook' -Message 'Management IP is empty.' `
                -Remediation 'Populate the ManagementIP column in the Hosts and Networks sheet.'))
        }
        elseif ($h.ip -notmatch $ipRegex) {
            $results.Add((New-VCFValidationResult -TestName "$label IP Format" -Target $h.ip `
                -Status 'Fail' -Category 'Workbook' `
                -Message "IP address '$($h.ip)' does not appear to be a valid IPv4 address." `
                -Remediation 'Correct the IP address in the workbook and regenerate the JSON.'))
        }
        else {
            $results.Add((New-VCFValidationResult -TestName "$label IP Format" -Target $h.ip `
                -Status 'Pass' -Category 'Workbook' -Message "IP address format is valid: $($h.ip)"))
        }
    }

    if ($hostIndex -eq 0) {
        $results.Add((New-VCFValidationResult -TestName 'Hosts Array' -Target $JsonPath `
            -Status 'Warn' -Category 'Workbook' -Message 'No host entries found in JSON.' `
            -Remediation 'Ensure the Hosts and Networks sheet is populated before converting.'))
    }

    $results | ForEach-Object { Write-Output $_ }
}
