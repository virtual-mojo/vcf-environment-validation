<#
.SYNOPSIS
    Converts a VCF Deployment Parameter Workbook to a structured JSON file.

.DESCRIPTION
    Reads key sheets from the Excel workbook and maps them into the JSON schema
    expected by the VCF installer appliance (or by this module's own validation
    functions). Requires the ImportExcel PowerShell module.

.PARAMETER WorkbookPath
    Path to the .xlsx workbook. Accepts pipeline input from Test-VCFWorkbook -PassThru.

.PARAMETER OutputPath
    Destination .json file path. Defaults to same folder as the workbook.

.PARAMETER Force
    Overwrite the output file if it already exists.

.EXAMPLE
    Convert-VCFWorkbookToJson -WorkbookPath '.\deployment-params.xlsx' -OutputPath '.\deployment.json'

.EXAMPLE
    Test-VCFWorkbook -WorkbookPath '.\deployment-params.xlsx' -PassThru |
        Convert-VCFWorkbookToJson -OutputPath '.\deployment.json' -Force

.OUTPUTS
    [System.IO.FileInfo] — the generated JSON file.
#>
function Convert-VCFWorkbookToJson {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$WorkbookPath,

        [string]$OutputPath,

        [switch]$Force
    )

    begin {
        $component = 'Convert-VCFWorkbookToJson'
    }

    process {
        # ── Resolve paths ──────────────────────────────────────────────────────
        $resolvedWorkbook = Resolve-Path $WorkbookPath -ErrorAction Stop

        if (-not $OutputPath) {
            $dir        = [System.IO.Path]::GetDirectoryName($resolvedWorkbook)
            $base       = [System.IO.Path]::GetFileNameWithoutExtension($resolvedWorkbook)
            $OutputPath = Join-Path $dir "$base.json"
        }

        if ((Test-Path $OutputPath) -and -not $Force) {
            Write-Error "Output file '$OutputPath' already exists. Use -Force to overwrite."
            return
        }

        # ── Dependency check ───────────────────────────────────────────────────
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Error "ImportExcel module is required. Install with: Install-Module ImportExcel -Scope CurrentUser"
            return
        }
        Import-Module ImportExcel -ErrorAction Stop

        Write-VCFLog -Message "Converting workbook '$resolvedWorkbook' → '$OutputPath'" -Level INFO -Component $component

        # ── Read sheets ────────────────────────────────────────────────────────
        # Each Import-Excel call targets a specific named range or sheet.
        # Adjust StartRow/HeaderRow to match your workbook version.

        $hostsRaw   = Import-Excel -Path $resolvedWorkbook -WorksheetName 'Hosts and Networks' -StartRow 2 -ErrorAction SilentlyContinue
        $vcenterRaw = Import-Excel -Path $resolvedWorkbook -WorksheetName 'vCenter'             -StartRow 2 -ErrorAction SilentlyContinue
        $nsxRaw     = Import-Excel -Path $resolvedWorkbook -WorksheetName 'NSX'                 -StartRow 2 -ErrorAction SilentlyContinue
        $sddcRaw    = Import-Excel -Path $resolvedWorkbook -WorksheetName 'SDDC Manager'        -StartRow 2 -ErrorAction SilentlyContinue
        $vsanRaw    = Import-Excel -Path $resolvedWorkbook -WorksheetName 'vSAN'                -StartRow 2 -ErrorAction SilentlyContinue

        # ── Map to canonical JSON structure ───────────────────────────────────
        $deployment = [ordered]@{
            schemaVersion = '1.0'
            generatedAt   = (Get-Date -Format 'o')
            sourceWorkbook = [System.IO.Path]::GetFileName($resolvedWorkbook)

            sddcManager   = if ($sddcRaw) { $sddcRaw | Select-Object * } else { $null }

            vcenter       = if ($vcenterRaw) {
                $vcenterRaw | ForEach-Object {
                    [ordered]@{
                        hostname    = $_.Hostname
                        ip          = $_.IPAddress
                        datacenter  = $_.Datacenter
                        cluster     = $_.Cluster
                    }
                }
            } else { @() }

            nsx           = if ($nsxRaw) { $nsxRaw | Select-Object * } else { $null }

            hosts         = if ($hostsRaw) {
                $hostsRaw | ForEach-Object {
                    [ordered]@{
                        fqdn        = $_.FQDN
                        ip          = $_.ManagementIP
                        username    = $_.Username
                        sshThumbprint = $_.SSHThumbprint
                        networkPool = $_.NetworkPool
                    }
                }
            } else { @() }

            vsan          = if ($vsanRaw) { $vsanRaw | Select-Object * } else { $null }
        }

        # ── Write output ───────────────────────────────────────────────────────
        if ($PSCmdlet.ShouldProcess($OutputPath, 'Write JSON file')) {
            $deployment | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
            Write-VCFLog -Message "JSON written: $OutputPath" -Level SUCCESS -Component $component
            Get-Item $OutputPath
        }
    }
}
